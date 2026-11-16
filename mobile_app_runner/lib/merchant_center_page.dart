import 'dart:io';

import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'merchant_map_preview.dart';
import 'app_translation.dart';

typedef Text = LocalizedText;

class MerchantCenterPage extends StatefulWidget {
  const MerchantCenterPage({super.key, required this.api});
  final ApiClient api;

  @override
  State<MerchantCenterPage> createState() => _MerchantCenterPageState();
}

class _MerchantCenterPageState extends State<MerchantCenterPage> {
  final _applicationKey = GlobalKey<FormState>();
  final _createKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final Map<String, TextEditingController> _fields = {};
  final Map<int, Map<String, TextEditingController>> _ads = {};
  final Map<int, List<XFile>> _adImages = {};
  XFile? _tinDocument;
  XFile? _bannerImage;
  Map<String, dynamic> _data = {};
  bool _loading = true;
  bool _busy = false;
  String? _businessCategory, _frequency;

  TextEditingController _field(String name) =>
      _fields.putIfAbsent(name, () => TextEditingController());

  TextEditingController _adField(int id, String name) => _ads
      .putIfAbsent(id, () => {})
      .putIfAbsent(name, () => TextEditingController());

  Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    for (final map in _ads.values) {
      for (final c in map.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      _data = await widget.api.get('/merchant');
      final merchant = _map(_data['merchant']);
      for (final key in [
        'business_name',
        'tin',
        'contact_name',
        'business_phone',
        'business_email',
        'address',
        'website_url',
      ]) {
        if (_field(key).text.isEmpty && merchant[key] != null) {
          _field(key).text = merchant[key].toString();
        }
      }
      final businessCategories = _strings(_data['business_categories']);
      final frequencies = _strings(_data['frequencies']);
      _businessCategory ??= businessCategories.isEmpty
          ? null
          : (businessCategories.contains(merchant['category'])
                ? merchant['category'].toString()
                : businessCategories.first);
      _frequency ??= frequencies.isEmpty ? null : frequencies.first;
      for (final value in (_data['ekubs'] as List? ?? const [])) {
        final ekub = _map(value);
        final id = int.tryParse('${ekub['id']}') ?? 0;
        final ad = _map(ekub['ad']);
        for (final key in [
          'title',
          'body',
          'website_url',
          'location',
        ]) {
          if (_adField(id, key).text.isEmpty && ad[key] != null) {
            _adField(id, key).text = ad[key].toString();
          }
        }
      }
    } on ApiException catch (e) {
      _data = {'error': e.message};
    }
    if (mounted) setState(() => _loading = false);
  }

  List<String> _strings(Object? values) =>
      (values as List? ?? const []).map((value) => value.toString()).toList();

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _submitApplication() async {
    if (!_applicationKey.currentState!.validate() ||
        _businessCategory == null) {
      return;
    }
    await _send(
      '/merchant/application',
      {
        'business_name': _field('business_name').text.trim(),
        'tin': _field('tin').text.trim(),
        'category': _businessCategory!,
        'business_phone': _field('business_phone').text.trim(),
        'address': _field('address').text.trim(),
        'website': _field('website_url').text.trim(),
        'location': _field('address').text.trim(),
      },
      files: _tinDocument == null
          ? const {}
          : {'tin_document': _tinDocument!.path},
    );
  }

  Future<void> _submitEkub() async {
    if (!_createKey.currentState!.validate() || _frequency == null) {
      return;
    }
    final saved = await _send(
      '/merchant/ekubs',
      {
        'name': _field('ekub_name').text.trim(),
        'category': (_map(_data['merchant'])['category'] ?? '').toString(),
        'frequency': _frequency!,
        'base_amount': double.tryParse(_field('base_amount').text) ?? 0,
        'duration': int.tryParse(_field('duration').text) ?? 0,
      },
      files: _bannerImage == null
          ? const {}
          : {'banner_image': _bannerImage!.path},
    );
    if (saved) {
      _field('ekub_name').clear();
      _field('base_amount').clear();
      _field('duration').text = '12';
      _bannerImage = null;
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _openCreateEkub() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final colors = Theme.of(sheetContext).colorScheme;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * .88,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  child: Form(
                    key: _createKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colors.outlineVariant,
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Create a private Ekub',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Share the invite code only with people you choose. Your approved merchant category is fixed for this Ekub.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _textField('ekub_name', 'Ekub name'),
                        const SizedBox(height: 12),
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Approved Ekub category',
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                          child: Text(
                            (_map(_data['merchant'])['category'] ?? 'Not set')
                                .toString(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          'base_amount',
                          'Contribution amount (ETB)',
                          keyboard: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) =>
                              double.tryParse(value ?? '') != null &&
                                  double.parse(value!) > 0
                              ? null
                              : 'Enter an amount above zero.',
                        ),
                        const SizedBox(height: 12),
                        _dropdown(
                          'Frequency',
                          _strings(_data['frequencies']),
                          _frequency,
                          (value) => setState(() => _frequency = value),
                        ),
                        const SizedBox(height: 12),
                        _textField(
                          'duration',
                          'Number of periods',
                          keyboard: TextInputType.number,
                          validator: (value) =>
                              int.tryParse(value ?? '') != null &&
                                  int.parse(value!) >= 2
                              ? null
                              : 'Enter at least 2 periods.',
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () async {
                                  await _pickEkubBanner();
                                  setSheetState(() {});
                                },
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(
                            _bannerImage == null
                                ? 'Add Ekub banner · max 1 MB'
                                : 'Change Ekub banner',
                          ),
                        ),
                        if (_bannerImage != null) ...[
                          const SizedBox(height: 9),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              File(_bannerImage!.path),
                              width: double.infinity,
                              height: 132,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          'This photo appears at the top of the Ekub cards.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _submitEkub,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(_busy ? 'Saving…' : 'Create Ekub'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _copyInviteCode(String code) async {
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    _message('Invite code copied.');
  }

  Future<void> _viewPhoto({XFile? file, String? url}) async {
    if (file == null && (url == null || url.isEmpty)) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(10),
          child: SizedBox(
            width: size.width,
            height: size.height * .82,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: .7,
                    maxScale: 5,
                    child: Center(
                      child: file != null
                          ? Image.file(File(file.path), fit: BoxFit.contain)
                          : Image.network(url!, fit: BoxFit.contain),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton.filledTonal(
                    tooltip: 'Close photo',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                const Positioned(
                  left: 12,
                  bottom: 10,
                  child: Text(
                    'Pinch to zoom · drag to move',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _send(
    String path,
    Map<String, dynamic> values, {
    Map<String, String> files = const {},
  }) async {
    setState(() => _busy = true);
    try {
      final fields = values.map((key, value) => MapEntry(key, '$value'));
      final response = files.isEmpty
          ? await widget.api.post(path, body: values)
          : await widget.api.postFiles(path, fields: fields, files: files);
      _message(response['message']?.toString() ?? 'Saved.');
      await _load();
      return true;
    } on ApiException catch (e) {
      _message(e.message);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTinDocument() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    if (await image.length() > 1024 * 1024) {
      _message('TIN document image must be 1 MB or smaller.');
      return;
    }
    setState(() => _tinDocument = image);
  }

  Future<void> _pickEkubBanner() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null) return;
    if (await image.length() > 1024 * 1024) {
      _message('Banner image must be 1 MB or smaller.');
      return;
    }
    setState(() => _bannerImage = image);
  }

  Future<void> _pickAdImages(int id) async {
    final images = await _picker.pickMultiImage(imageQuality: 88);
    if (images.isEmpty) return;
    if (images.length > 3 ||
        (await Future.wait(
          images.map((image) => image.length()),
        )).any((size) => size > 1024 * 1024)) {
      _message('Choose up to 3 images, each 1 MB or smaller.');
      return;
    }
    setState(() => _adImages[id] = images);
  }

  Widget _textField(
    String key,
    String label, {
    TextInputType? keyboard,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: _field(key),
    keyboardType: keyboard,
    maxLines: maxLines,
    decoration: _inputDecoration(label, hint: hint),
    validator:
        validator ??
        (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
  );

  Widget _dropdown(
    String label,
    List<String> values,
    String? selected,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String>(
    value: values.contains(selected) ? selected : null,
    isExpanded: true,
    decoration: _inputDecoration(label),
    items: values
        .map((value) => DropdownMenuItem(value: value, child: Text(value)))
        .toList(),
    onChanged: onChanged,
  );

  InputDecoration _inputDecoration(String label, {String? hint}) =>
      InputDecoration(
        labelText: mekenetTranslate(label),
        hintText: hint == null ? null : mekenetTranslate(hint),
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withAlpha(95),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      );

  Future<void> _openMap(Map ad, Map merchant) async {
    final lat = ad['latitude'] ?? merchant['location_lat'];
    final lng = ad['longitude'] ?? merchant['location_lng'];
    if (lat == null || lng == null) {
      _message('This merchant has not added map coordinates yet.');
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final merchant = _map(_data['merchant']);
    final status = merchant['status']?.toString() ?? '';
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Merchant center')),
      backgroundColor: colors.surface,
      floatingActionButton: status == 'approved'
          ? FloatingActionButton.large(
              onPressed: _busy ? null : _openCreateEkub,
              tooltip: 'Create a private Ekub',
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              child: const Icon(Icons.add_rounded, size: 31),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: _data['error'] != null
          ? Center(child: Text(_data['error'].toString()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  status == 'approved' ? 96 : 16,
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(19),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2E9868), Color(0xFF49B3C2)],
                      ),
                      borderRadius: BorderRadius.circular(23),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E9868).withAlpha(45),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(38),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                status == 'approved'
                                    ? '${merchant['business_name']} dashboard'
                                    : 'Merchant account',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Private Ekubs, invited members, and business updates in one place.',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(235),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (status == 'pending')
                    _pending(merchant)
                  else if (status == 'approved')
                    ..._dashboard()
                  else
                    _applicationForm(merchant),
                ],
              ),
            ),
    );
  }

  Widget _pending(Map merchant) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_top_rounded, size: 34, color: Colors.teal),
          const SizedBox(height: 12),
          const Text(
            'Application under review',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${merchant['business_name']} · ${merchant['category']} · TIN ending ${merchant['tin_last_four'] ?? '••••'}',
          ),
          const SizedBox(height: 8),
          const Text(
            'Merchant tools become available after the admin verifies your information.',
          ),
        ],
      ),
    ),
  );

  Widget _applicationForm(Map merchant) {
    if (merchant['rejection_reason'] != null) {
      _field('business_name').text = _field('business_name').text.isEmpty
          ? (merchant['business_name'] ?? '').toString()
          : _field('business_name').text;
    }
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(23),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _applicationKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Business verification',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Submit your TIN and business details for manual admin review.',
              ),
              if (merchant['rejection_reason'] != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Admin note: ${merchant['rejection_reason']}',
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 12),
              _fieldGap(_textField('business_name', 'Business name')),
              _fieldGap(
                _textField(
                  'tin',
                  'TIN (10 digits)',
                  keyboard: TextInputType.number,
                  validator: (value) =>
                      RegExp(r'^\d{10}$').hasMatch((value ?? '').trim())
                      ? null
                      : 'Enter the 10 digit TIN.',
                ),
              ),
              _fieldGap(
                _dropdown(
                  'Business category',
                  _strings(_data['business_categories']),
                  _businessCategory,
                  (value) => setState(() => _businessCategory = value),
                ),
              ),
              _fieldGap(_textField('contact_name', 'Contact person')),
              _fieldGap(
                _textField(
                  'business_phone',
                  'Business phone',
                  keyboard: TextInputType.phone,
                ),
              ),
              _fieldGap(
                _textField(
                  'business_email',
                  'Business email',
                  keyboard: TextInputType.emailAddress,
                  validator: (value) =>
                      value == null || value.isEmpty || value.contains('@')
                      ? null
                      : 'Enter a valid email.',
                ),
              ),
              _fieldGap(
                _textField(
                  'address',
                  'Business location and address',
                  hint: 'Area, landmark, city · e.g. Bole, Addis Ababa',
                  maxLines: 2,
                ),
              ),
              _fieldGap(
                _textField(
                  'website_url',
                  'Website link (optional)',
                  keyboard: TextInputType.url,
                  validator: (value) =>
                      value == null ||
                          value.isEmpty ||
                          Uri.tryParse(value)?.hasAbsolutePath == true
                      ? null
                      : 'Enter a valid link.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'This place appears on your Ekub map. We find it from the location name; no coordinates needed.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickTinDocument,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(
                  _tinDocument == null
                      ? 'Add TIN document image · max 1 MB'
                      : 'TIN document selected',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submitApplication,
                  child: Text(_busy ? 'Submitting…' : 'Submit for approval'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldGap(Widget child) =>
      Padding(padding: const EdgeInsets.only(bottom: 12), child: child);

  List<Widget> _dashboard() {
    final ekubs = _data['ekubs'] as List? ?? const [];
    final commissions = _data['commissions'] as List? ?? const [];
    return [
      Row(
        children: [
          Expanded(
            child: _metric('Commission earned', _money(_data['earned'])),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _metric(
              'Awaiting payout',
              _money(_data['pending_commission']),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your private Ekubs',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  'Ekubs in your approved business category',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '${ekubs.length}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      if (ekubs.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Text('You have not created an Ekub yet.'),
          ),
        ),
      ...ekubs.map((value) => _ekubCard(_map(value))),
      const SizedBox(height: 12),
      Text(
        'Commission ledger',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
      const Text(
        'Commission is recorded after the admin draws a winner. Payment review and payout control remain with admins.',
      ),
      if (commissions.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Text('No commissions yet.'),
          ),
        ),
      ...commissions.map((value) {
        final row = _map(value);
        return Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text((row['ekub_name'] ?? 'Ekub').toString()),
            subtitle: Text('Period ${row['period_no']} · ${row['status']}'),
            trailing: Text(
              _money(row['commission_amount']),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        );
      }),
    ];
  }

  Widget _metric(String title, String value) {
    final pending = title.toLowerCase().contains('awaiting');
    final accent = pending ? const Color(0xFF299EB0) : const Color(0xFF38996B);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(color: accent.withAlpha(45)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withAlpha(25), accent.withAlpha(7)],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withAlpha(32),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                pending
                    ? Icons.hourglass_bottom_rounded
                    : Icons.account_balance_wallet_rounded,
                color: accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$value ETB',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ekubCard(Map ekub) {
    final id = int.tryParse('${ekub['id']}') ?? 0;
    final requests = ekub['requests'] as List? ?? const [];
    final members = ekub['members'] as List? ?? const [];
    final ad = _map(ekub['ad']);
    final images = ad['images'] as List? ?? const [];
    final bannerUrl = (ekub['merchant_banner_url'] ?? '').toString();
    final localPhotos = _adImages[id] ?? const <XFile>[];
    final inviteCode = (ekub['join_code'] ?? '').toString();
    final category = (ekub['category'] ?? 'Ekub').toString();
    final name = (ekub['name'] ?? 'Ekub').toString();
    final cover = localPhotos.isNotEmpty
        ? GestureDetector(
            onTap: () => _viewPhoto(file: localPhotos.first),
            child: Image.file(
              File(localPhotos.first.path),
              width: double.infinity,
              height: 182,
              fit: BoxFit.cover,
            ),
          )
        : bannerUrl.isNotEmpty
        ? GestureDetector(
            onTap: () => _viewPhoto(url: bannerUrl),
            child: Image.network(
              bannerUrl,
              width: double.infinity,
              height: 182,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _ekubCoverPlaceholder(),
            ),
          )
        : images.isNotEmpty
        ? GestureDetector(
            onTap: () => _viewPhoto(url: images.first.toString()),
            child: Image.network(
              images.first.toString(),
              width: double.infinity,
              height: 182,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _ekubCoverPlaceholder(),
            ),
          )
        : _ekubCoverPlaceholder();
    return Card(
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 182,
            child: Stack(
              fit: StackFit.expand,
              children: [
                cover,
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha(8),
                          Colors.black.withAlpha(185),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 13,
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(230),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(
                            '${category.toUpperCase()} EKUB',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (images.isNotEmpty || localPhotos.isNotEmpty)
                  const Positioned(
                    top: 10,
                    right: 10,
                    child: IgnorePointer(
                      child: Icon(
                        Icons.zoom_in_rounded,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _infoChip(Icons.schedule_rounded, '${ekub['frequency']}'),
                    _infoChip(
                      Icons.payments_outlined,
                      '${_money(ekub['base_amount'])} ETB',
                    ),
                    _infoChip(
                      Icons.calendar_month_outlined,
                      '${ekub['duration']} periods',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'INVITE CODE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              inviteCode,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copy invite code',
                            onPressed: inviteCode.isEmpty
                                ? null
                                : () => _copyInviteCode(inviteCode),
                            icon: const Icon(Icons.copy_rounded),
                          ),
                        ],
                      ),
                      Text(
                        '${members.length} members · ${requests.length} pending requests',
                      ),
                    ],
                  ),
                ),
                if (requests.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Join requests',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  ...requests.map((value) {
                    final request = _map(value);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${request['first_name']} ${request['last_name']}',
                      ),
                      subtitle: Text(
                        '@${request['username']} · ${request['phone']} · ${request['share_type']} share',
                      ),
                      trailing: Wrap(
                        spacing: 3,
                        children: [
                          IconButton(
                            tooltip: 'Approve',
                            onPressed: _busy
                                ? null
                                : () => _decide(_int(request['id']), 'approve'),
                            icon: const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Reject',
                            onPressed: _busy
                                ? null
                                : () => _decide(_int(request['id']), 'reject'),
                            icon: const Icon(
                              Icons.cancel_outlined,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('Member information (${members.length})'),
                  children: members.map((value) {
                    final member = _map(value);
                    final memberName =
                        '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'
                            .trim();
                    final imageUrl = (member['profile_picture_url'] ?? '')
                        .toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        foregroundImage: imageUrl.isEmpty
                            ? null
                            : NetworkImage(imageUrl),
                        onForegroundImageError: imageUrl.isEmpty
                            ? null
                            : (_, __) {},
                        child: Text(
                          memberName.isEmpty
                              ? 'M'
                              : memberName[0].toUpperCase(),
                        ),
                      ),
                      title: Text(memberName.isEmpty ? 'Member' : memberName),
                      subtitle: Text(
                        '@${member['username']} · ${member['phone']}',
                      ),
                      trailing: Text(_money(member['contribution_amount'])),
                    );
                  }).toList(),
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Advertisement and location'),
                  children: [
                    TextFormField(
                      controller: _adField(id, 'title'),
                      decoration: _inputDecoration('Advertisement title'),
                    ),
                    TextFormField(
                      controller: _adField(id, 'body'),
                      maxLines: 3,
                      decoration: _inputDecoration('Products or services'),
                    ),
                    TextFormField(
                      controller: _adField(id, 'website_url'),
                      keyboardType: TextInputType.url,
                      decoration: _inputDecoration('Website link'),
                    ),
                    TextFormField(
                      controller: _adField(id, 'location'),
                      decoration: _inputDecoration(
                        'Location on this Ekub',
                        hint: 'Area, landmark, city',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => _pickAdImages(id),
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          '${localPhotos.length > 0 ? localPhotos.length : images.length} / 3 images · max 1 MB each',
                        ),
                      ),
                    ),
                    if (localPhotos.isNotEmpty)
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: localPhotos.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 9),
                          itemBuilder: (_, index) => GestureDetector(
                            onTap: () => _viewPhoto(file: localPhotos[index]),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(localPhotos[index].path),
                                width: 112,
                                height: 88,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (images.isNotEmpty)
                      SizedBox(
                        height: 88,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 9),
                          itemBuilder: (_, index) {
                            final imageUrl = images[index].toString();
                            return GestureDetector(
                              onTap: () => _viewPhoto(url: imageUrl),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  imageUrl,
                                  width: 112,
                                  height: 88,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _busy ? null : () => _saveAd(ekub, id),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save advertisement'),
                      ),
                    ),
                  ],
                ),
                if (ad.isNotEmpty)
                  _mapPreview(ad, ekub, merchant: _map(_data['merchant'])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ekubCoverPlaceholder() => Container(
    height: 182,
    width: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF318F69), Color(0xFF43A9BA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    alignment: Alignment.center,
    child: const Icon(
      Icons.storefront_rounded,
      color: Colors.white70,
      size: 56,
    ),
  );

  Widget _infoChip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withAlpha(120),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _mapPreview(Map ad, Map ekub, {required Map merchant}) {
    final location =
        (ad['location'] ?? merchant['address'] ?? 'Merchant location')
            .toString();
    final lat = double.tryParse(
      '${ad['latitude'] ?? merchant['location_lat']}',
    );
    final lng = double.tryParse(
      '${ad['longitude'] ?? merchant['location_lng']}',
    );
    if (lat == null || lng == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: MerchantMapPreview(
        latitude: lat,
        longitude: lng,
        location: location,
        onTap: () => _openMap(ad, merchant),
        height: 150,
      ),
    );
  }

  Future<void> _decide(int requestId, String action) async {
    await _send('/merchant/requests/$requestId/$action', const {});
  }

  Future<void> _saveAd(Map ekub, int id) async {
    final picked = _adImages[id] ?? const <XFile>[];
    await _send(
      '/merchant/ekubs/$id/ad',
      {
        'title': _adField(id, 'title').text.trim().isEmpty
            ? (merchantName)
            : _adField(id, 'title').text.trim(),
        'body': _adField(id, 'body').text.trim(),
        'website_url': _adField(id, 'website_url').text.trim(),
        'location': _adField(id, 'location').text.trim(),
      },
      files: {
        for (var i = 0; i < picked.length; i++) 'images[$i]': picked[i].path,
      },
    );
    _adImages.remove(id);
  }

  String get merchantName =>
      (_map(_data['merchant'])['business_name'] ?? 'Merchant ad').toString();
  String _money(Object? value) {
    final number = double.tryParse('$value') ?? 0;
    return number.toStringAsFixed(2);
  }

  int _int(Object? value) => int.tryParse('$value') ?? 0;
}
