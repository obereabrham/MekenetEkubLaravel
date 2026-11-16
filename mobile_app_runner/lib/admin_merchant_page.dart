import 'package:flutter/material.dart';

import 'api.dart';

const _adminGreen = Color(0xFF88B44A);
const _adminSky = Color(0xFF43B5D4);

class AdminMerchantPage extends StatefulWidget {
  const AdminMerchantPage({
    super.key,
    required this.api,
    required this.user,
    required this.onSignOut,
  });

  final ApiClient api;
  final Map<String, dynamic> user;
  final Future<void> Function() onSignOut;

  @override
  State<AdminMerchantPage> createState() => _AdminMerchantPageState();
}

class _AdminMerchantPageState extends State<AdminMerchantPage> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _merchants = [];
  List<Map<String, dynamic>> _commissions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await widget.api.get('/admin/merchants');
      if (!mounted) return;
      setState(() {
        _merchants = (response['merchants'] as List? ?? const [])
            .map(_asMap)
            .toList();
        _commissions = (response['commissions'] as List? ?? const [])
            .map(_asMap)
            .toList();
      });
    } catch (exception) {
      if (mounted) setState(() => _error = exception.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reviewMerchant(
    Map<String, dynamic> merchant,
    String action,
  ) async {
    String? reason;
    if (action == 'reject') {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reject merchant application'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason for rejection',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(dialogContext, controller.text.trim());
                }
              },
              child: const Text('Reject application'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null) return;
    } else {
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Approve merchant?'),
          content: Text(
            'Approving ${merchant['business_name'] ?? 'this business'} lets its owner create merchant Ekubs and manage member requests.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Approve'),
            ),
          ],
        ),
      );
      if (approved != true) return;
    }

    setState(() => _busy = true);
    try {
      final body = action == 'reject'
          ? {'reason': reason!}
          : const <String, dynamic>{};
      final response = await widget.api.post(
        '/admin/merchants/${_asInt(merchant['id'])}/$action',
        body: body,
      );
      if (mounted) _showMessage(response['message'] ?? 'Application updated.');
      await _load();
    } catch (exception) {
      if (mounted) _showMessage(exception.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markCommissionPaid(Map<String, dynamic> commission) async {
    final paid = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record commission as paid?'),
        content: Text(
          'Only continue after the ${_money(commission['amount'])} transfer to ${commission['business_name'] ?? 'the merchant'} is complete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Mark paid'),
          ),
        ],
      ),
    );
    if (paid != true) return;

    setState(() => _busy = true);
    try {
      final response = await widget.api.post(
        '/admin/merchant-commissions/${_asInt(commission['id'])}/paid',
      );
      if (mounted) _showMessage(response['message'] ?? 'Commission updated.');
      await _load();
    } catch (exception) {
      if (mounted) _showMessage(exception.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(dynamic message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final pending = _merchants
        .where((merchant) => merchant['status'] == 'pending')
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Merchant review',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _loading || _busy ? null : _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: widget.onSignOut,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0x1F88B44A),
                      child: Icon(
                        Icons.storefront_outlined,
                        color: _adminGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Admin portal',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Signed in as @${widget.user['username'] ?? 'admin'}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${pending.length}',
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            color: _adminGreen,
                          ),
                        ),
                        Text(
                          'Pending',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Merchant applications',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorCard(message: _error!, onRetry: _load)
            else if (_merchants.isEmpty)
              const _EmptyCard(message: 'No merchant applications yet.')
            else
              ..._merchants.map(_merchantCard),
            const SizedBox(height: 20),
            const Text(
              'Pending merchant commissions',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
            ),
            const SizedBox(height: 8),
            if (!_loading && _commissions.isEmpty)
              const _EmptyCard(
                message: 'No commissions are waiting for payout.',
              ),
            ..._commissions.map(_commissionCard),
          ],
        ),
      ),
    );
  }

  Widget _merchantCard(Map<String, dynamic> merchant) {
    final pending = merchant['status'] == 'pending';
    final name =
        '${merchant['first_name'] ?? ''} ${merchant['last_name'] ?? ''}'.trim();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (merchant['business_name'] ?? 'Business').toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ),
                _StatusPill(
                  status: (merchant['status'] ?? 'pending').toString(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('$name · @${merchant['username'] ?? ''}'),
            const SizedBox(height: 5),
            Text('Category: ${merchant['category'] ?? '—'}'),
            Text('TIN: ${merchant['tin'] ?? '—'}'),
            Text(
              'Phone: ${merchant['business_phone'] ?? merchant['phone'] ?? '—'}',
            ),
            Text('Address: ${merchant['address'] ?? '—'}'),
            if ((merchant['website'] ?? '').toString().isNotEmpty)
              Text('Website: ${merchant['website']}'),
            if ((merchant['rejection_reason'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Reason: ${merchant['rejection_reason']}',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            if (pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _reviewMerchant(merchant, 'reject'),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _reviewMerchant(merchant, 'approve'),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _commissionCard(Map<String, dynamic> commission) => Card(
    margin: const EdgeInsets.symmetric(vertical: 6),
    child: ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0x1F43B5D4),
        child: Icon(Icons.payments_outlined, color: _adminSky),
      ),
      title: Text(
        (commission['business_name'] ?? 'Merchant').toString(),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${commission['ekub_name'] ?? 'Ekub'} · ${_money(commission['amount'])}',
      ),
      trailing: TextButton(
        onPressed: _busy ? null : () => _markCommissionPaid(commission),
        child: const Text('Mark paid'),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'approved'
        ? _adminGreen
        : status == 'rejected'
        ? Colors.redAccent
        : _adminSky;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Center(child: Text(message, textAlign: TextAlign.center)),
    ),
  );
}

Map<String, dynamic> _asMap(dynamic value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value))
    : <String, dynamic>{};

int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

String _money(dynamic value) =>
    '${double.tryParse(value?.toString() ?? '')?.toStringAsFixed(2) ?? '0.00'} ETB';
