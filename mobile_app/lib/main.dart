import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';

const bg = Color(0xFF071512);
const panel = Color(0xFF10251D);
const green = Color(0xFF23B765);
const blue = Color(0xFF039BC8);
const muted = Color(0xFFAAC0B7);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  await api.restoreToken();
  runApp(MekenetApp(api: api));
}

class MekenetApp extends StatefulWidget {
  const MekenetApp({super.key, required this.api});
  final ApiClient api;

  @override
  State<MekenetApp> createState() => _MekenetAppState();
}

class _MekenetAppState extends State<MekenetApp> {
  Map<String, dynamic>? user;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    if (await widget.api.hasToken()) {
      try {
        user = _map((await widget.api.get('/me'))['user']);
      } catch (_) {
        await widget.api.clearToken();
      }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _signOut() async {
    try {
      await widget.api.post('/auth/logout');
    } catch (_) {}
    await widget.api.clearToken();
    if (mounted) setState(() => user = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(
      seedColor: green,
      brightness: Brightness.dark,
      primary: green,
      secondary: blue,
      surface: panel,
    );
    return MaterialApp(
      title: 'Mekenet Ekub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: bg,
        appBarTheme: const AppBarTheme(backgroundColor: bg, foregroundColor: Colors.white),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: green)),
          labelStyle: const TextStyle(color: muted),
        ),
      ),
      home: loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : user == null
              ? AuthPage(api: widget.api, onSignedIn: (value) => setState(() => user = value))
              : MemberPage(api: widget.api, user: user!, onSignOut: _signOut),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.api, required this.onSignedIn});
  final ApiClient api;
  final ValueChanged<Map<String, dynamic>> onSignedIn;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final form = GlobalKey<FormState>();
  final login = TextEditingController();
  final password = TextEditingController();
  final code = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final username = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final confirmation = TextEditingController();

  bool registering = false;
  bool busy = false;
  String? challengeId;
  String? emailHint;
  String? emailNotice;
  String method = 'email';
  List<String> methods = [];
  String? error;
  String? notice;

  @override
  void dispose() {
    for (final controller in [
      login,
      password,
      code,
      firstName,
      lastName,
      username,
      phone,
      email,
      confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      if (registering) {
        final response = await widget.api.post(
          '/auth/register',
          authenticated: false,
          body: {
            'first_name': firstName.text.trim(),
            'last_name': lastName.text.trim(),
            'username': username.text.trim(),
            'phone': phone.text.trim(),
            'email': email.text.trim().isEmpty ? null : email.text.trim(),
            'password': password.text,
            'password_confirmation': confirmation.text,
            'device_name': 'Mekenet mobile',
          },
        );
        setState(() {
          registering = false;
          login.text = username.text.trim();
          password.clear();
          confirmation.clear();
          notice = response['message']?.toString();
        });
      } else {
        final response = await widget.api.post(
          '/auth/login',
          authenticated: false,
          body: {
            'login': login.text.trim(),
            'password': password.text,
            'device_name': 'Mekenet mobile',
          },
        );
        if (response['two_factor_required'] == true) {
          methods = (response['methods'] as List? ?? const [])
              .map((value) => value.toString())
              .toList();
          challengeId = response['challenge_id']?.toString();
          emailHint = response['email_hint']?.toString();
          emailNotice = response['email_notice']?.toString();
          method = methods.contains('email') ? 'email' : 'authenticator';
          setState(() => notice = emailNotice);
        } else {
          await _acceptToken(response);
        }
      }
    } on ApiException catch (exception) {
      setState(() => error = exception.message);
    } catch (_) {
      setState(() => error = 'Could not complete this request.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verifyCode() async {
    if (challengeId == null || code.text.trim().isEmpty) {
      setState(() => error = 'Enter the verification code.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await widget.api.post(
        '/auth/2fa/verify',
        authenticated: false,
        body: {
          'challenge_id': challengeId,
          'method': method,
          'code': code.text.trim(),
        },
      );
      await _acceptToken(response);
    } on ApiException catch (exception) {
      setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _resendCode() async {
    if (challengeId == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await widget.api.post(
        '/auth/2fa/resend',
        authenticated: false,
        body: {'challenge_id': challengeId},
      );
      setState(() => notice = response['message']?.toString());
    } on ApiException catch (exception) {
      setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _acceptToken(Map<String, dynamic> response) async {
    final token = response['access_token']?.toString() ?? '';
    if (token.isEmpty) {
      setState(() => error = 'The site did not return a sign-in token.');
      return;
    }
    await widget.api.saveToken(token);
    widget.onSignedIn(_map(response['user']));
  }

  @override
  Widget build(BuildContext context) {
    final checkingCode = challengeId != null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Brand(),
                    const SizedBox(height: 28),
                    Text(
                      checkingCode ? 'Verify it’s you' : registering ? 'Create your account' : 'Welcome back',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      checkingCode
                          ? 'Enter the code from your authenticator app or email.'
                          : registering
                              ? 'Create a member account for Mekenet Ekub.'
                              : 'Sign in to browse Ekubs and track contributions.',
                      style: const TextStyle(color: muted, height: 1.4),
                    ),
                    const SizedBox(height: 21),
                    if (checkingCode)
                      _verificationFields()
                    else if (registering)
                      _registrationFields()
                    else
                      _loginFields(),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      _Message(text: error!, isError: true),
                    ],
                    if (notice != null) ...[
                      const SizedBox(height: 12),
                      _Message(text: notice!, isError: false),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: busy ? null : checkingCode ? _verifyCode : submit,
                      child: busy
                          ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(checkingCode ? 'Verify and continue' : registering ? 'Create account' : 'Sign in'),
                    ),
                    if (checkingCode) ...[
                      if (methods.length > 1)
                        Wrap(
                          alignment: WrapAlignment.center,
                          children: methods.map((value) {
                            final label = value == 'email' ? 'email code' : 'authenticator';
                            return TextButton(
                              onPressed: busy
                                  ? null
                                  : () => setState(() {
                                        method = value;
                                        code.clear();
                                        notice = value == 'email'
                                            ? emailNotice
                                            : 'Enter the current code from your authenticator app.';
                                      }),
                              child: Text(method == value ? 'Using $label' : 'Use $label'),
                            );
                          }).toList(),
                        ),
                      if (method == 'email')
                        TextButton(onPressed: busy ? null : _resendCode, child: const Text('Resend email code')),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                  challengeId = null;
                                  methods = [];
                                  code.clear();
                                  error = null;
                                  notice = null;
                                }),
                        child: const Text('Back to sign in'),
                      ),
                    ] else
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                  registering = !registering;
                                  error = null;
                                  notice = null;
                                }),
                        child: Text(registering ? 'I already have an account' : 'Create a new account'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginFields() => Column(
        children: [
          TextFormField(
            controller: login,
            decoration: const InputDecoration(labelText: 'Username, phone, or email', prefixIcon: Icon(Icons.person_outline)),
            validator: (value) => value == null || value.trim().isEmpty ? 'Enter your sign-in details.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
            validator: (value) => value == null || value.isEmpty ? 'Enter your password.' : null,
          ),
        ],
      );

  Widget _registrationFields() => Column(
        children: [
          Row(children: [
            Expanded(child: _field(firstName, 'First name')),
            const SizedBox(width: 9),
            Expanded(child: _field(lastName, 'Last name')),
          ]),
          const SizedBox(height: 10),
          _field(username, 'Username'),
          const SizedBox(height: 10),
          _field(phone, 'Phone number', keyboard: TextInputType.phone),
          const SizedBox(height: 10),
          _field(email, 'Email (optional)', required: false, keyboard: TextInputType.emailAddress),
          const SizedBox(height: 10),
          TextFormField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password', helperText: '8+ characters, uppercase, number, and symbol'),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Enter a password.';
              if (value.length < 8 ||
                  !RegExp(r'[A-Z]').hasMatch(value) ||
                  !RegExp(r'\d').hasMatch(value) ||
                  !RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
                return 'Use the required password format.';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: confirmation,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm password'),
            validator: (value) => value != password.text ? 'Passwords do not match.' : null,
          ),
        ],
      );

  Widget _verificationFields() => Column(
        children: [
          if (method == 'email' && emailHint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Code sent to $emailHint', style: const TextStyle(color: muted)),
            ),
          TextFormField(
            controller: code,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: method == 'email' ? 'Email verification code' : 'Authenticator code'),
          ),
        ],
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    TextInputType? keyboard,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
        validator: (value) => required && (value == null || value.trim().isEmpty) ? 'Enter $label.' : null,
      );
}

class MemberPage extends StatefulWidget {
  const MemberPage({super.key, required this.api, required this.user, required this.onSignOut});
  final ApiClient api;
  final Map<String, dynamic> user;
  final Future<void> Function() onSignOut;

  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {
  int selected = 0;

  void _selectTab(int index) => setState(() => selected = index);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardView(api: widget.api, user: widget.user, onNavigate: _selectTab),
      ExploreView(api: widget.api),
      MyEkubsView(api: widget.api, onShowStatus: () => _selectTab(3), onBrowse: () => _selectTab(1)),
      StatusView(api: widget.api),
      ProfileView(api: widget.api, user: widget.user, onSignOut: widget.onSignOut),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Mekenet Ekub', style: TextStyle(fontWeight: FontWeight.w800))),
      body: IndexedStack(index: selected, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'My Ekubs'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Payments'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class DashboardView extends StatefulWidget {
  const DashboardView({super.key, required this.api, required this.user, required this.onNavigate});
  final ApiClient api;
  final Map<String, dynamic> user;
  final ValueChanged<int> onNavigate;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  bool loading = true;
  String? error;
  int joinedCount = 0;
  double dueTotal = 0;
  double pendingTotal = 0;
  List<dynamic> featured = [];
  final Set<int> joiningIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final responses = await Future.wait([
        widget.api.get('/ekubs'),
        widget.api.get('/my/ekubs'),
        widget.api.get('/my/status'),
      ]);
      final available = responses[0]['data'] as List? ?? [];
      final joined = responses[1]['data'] as List? ?? [];
      final status = responses[2]['data'] as List? ?? [];
      var due = 0.0;
      var pending = 0.0;
      for (final row in status) {
        final group = _map(row);
        for (final value in group['periods'] as List? ?? []) {
          final period = _map(value);
          pending += _num(period['pending']);
          if (period['can_pay'] == true) due += _num(period['available_to_pay']);
        }
      }
      joinedCount = joined.length;
      dueTotal = due;
      pendingTotal = pending;
      featured = available.take(4).toList();
    } on ApiException catch (exception) {
      error = exception.message;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _join(Map<String, dynamic> item) async {
    final id = _int(item['id']);
    if (!joiningIds.add(id)) return;
    if (mounted) setState(() {});
    final joined = await _joinEkub(context, widget.api, item);
    if (joined) await _load();
    joiningIds.remove(id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (widget.user['first_name'] ?? 'there').toString();
    final tileWidth = ((MediaQuery.sizeOf(context).width - 52) / 2).clamp(140.0, 260.0);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [green, blue]),
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.savings_outlined, size: 29),
              const SizedBox(height: 12),
              Text('Welcome, ' + firstName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Build your future together. Your Ekub activity is all in one place.', style: TextStyle(height: 1.35)),
            ]),
          ),
          const SizedBox(height: 18),
          Text('Your overview', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 9),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.15,
            children: [
              _OverviewTile(icon: Icons.groups_outlined, label: 'My Ekubs', value: joinedCount.toString()),
              _OverviewTile(icon: Icons.payments_outlined, label: 'Due now', value: _money(dueTotal)),
              _OverviewTile(icon: Icons.hourglass_top, label: 'Pending review', value: _money(pendingTotal)),
              _OverviewTile(icon: Icons.verified_user_outlined, label: 'KYC', value: (widget.user['kyc_status'] ?? 'Not submitted').toString().replaceAll('_', ' ')),
            ],
          ),
          const SizedBox(height: 19),
          Text('Quick access', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 9),
          Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(width: tileWidth, child: _HomeAction(icon: Icons.explore_outlined, title: 'Browse Ekubs', onTap: () => widget.onNavigate(1))),
            SizedBox(width: tileWidth, child: _HomeAction(icon: Icons.groups_outlined, title: 'My Ekubs', onTap: () => widget.onNavigate(2))),
            SizedBox(width: tileWidth, child: _HomeAction(icon: Icons.receipt_long_outlined, title: 'Payment status', onTap: () => widget.onNavigate(3))),
            SizedBox(width: tileWidth, child: _HomeAction(icon: Icons.person_outline, title: 'Profile & more', onTap: () => widget.onNavigate(4))),
          ]),
          if (error != null) ...[
            const SizedBox(height: 12),
            _Retry(text: error!, onRetry: _load),
          ],
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(22), child: CircularProgressIndicator()))
          else if (featured.isNotEmpty) ...[
            const SizedBox(height: 19),
            Text('Available Ekubs', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 620 ? 3 : 2;
              final cardHeight = constraints.maxWidth < 360 ? 246.0 : 258.0;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: featured.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: cardHeight,
                ),
                itemBuilder: (context, index) {
                  final item = _map(featured[index]);
                  final canJoin = item['joined'] != true && item['status'] == 'open' && item['is_full'] != true;
                  return _HomeEkubCard(
                    item: item,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EkubDetails(api: widget.api, id: _int(item['id'])))),
                    onJoin: canJoin ? () => _join(item) : null,
                    actionLabel: item['joined'] == true ? 'Joined' : item['is_full'] == true ? 'Full' : 'Join',
                    busy: joiningIds.contains(_int(item['id'])),
                  );
                },
              );
            }),
            TextButton.icon(
              onPressed: () => widget.onNavigate(1),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('See all available Ekubs'),
            ),
          ] else if (!loading) ...[
            const SizedBox(height: 12),
            const _Empty(text: 'There are no open Ekubs right now. Pull down to refresh.'),
          ],
        ],
      ),
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF203A30))),
        child: Row(children: [
          Icon(icon, color: green, size: 20),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: const TextStyle(color: muted, fontSize: 11)),
            const SizedBox(height: 3),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ])),
        ]),
      );
}

class _HomeAction extends StatelessWidget {
  const _HomeAction({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(children: [
              Icon(icon, color: green),
              const SizedBox(width: 9),
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
              const Icon(Icons.chevron_right, color: muted, size: 19),
            ]),
          ),
        ),
      );
}

class ExploreView extends StatefulWidget {
  const ExploreView({super.key, required this.api});
  final ApiClient api;

  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  final search = TextEditingController();
  List<dynamic> rows = [];
  List<String> categories = [];
  List<String> frequencies = [];
  String category = 'All categories';
  String frequency = 'All frequencies';
  bool loading = true;
  bool joining = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final response = await widget.api.get('/ekubs');
      rows = response['data'] as List? ?? [];
      categories = (response['categories'] as List? ?? const []).map((value) => value.toString()).toList();
      frequencies = (response['frequencies'] as List? ?? const []).map((value) => value.toString()).toList();
    } on ApiException catch (exception) {
      error = exception.message;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _join(Map<String, dynamic> item) async {
    if (joining) return;
    setState(() => joining = true);
    final joined = await _joinEkub(context, widget.api, item);
    if (joined) await _load();
    if (mounted) setState(() => joining = false);
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final visible = rows.where((row) {
      final item = _map(row);
      final matchesQuery = query.isEmpty ||
          (item['name'] ?? '').toString().toLowerCase().contains(query) ||
          (item['category'] ?? '').toString().toLowerCase().contains(query) ||
          (item['frequency'] ?? '').toString().toLowerCase().contains(query);
      return (category == 'All categories' || item['category'] == category) &&
          (frequency == 'All frequencies' || item['frequency'] == frequency) &&
          matchesQuery;
    }).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [green, blue]), borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.all(19),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.savings_outlined, size: 29),
            SizedBox(height: 11),
            Text('Build your future together.', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            SizedBox(height: 6),
            Text('Find a community Ekub that fits your goals.'),
          ]),
        ),
        const SizedBox(height: 13),
        TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Search Ekubs', prefixIcon: Icon(Icons.search))),
        const SizedBox(height: 9),
        DropdownButtonFormField<String>(
          value: category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            const DropdownMenuItem(value: 'All categories', child: Text('All categories')),
            ...categories.map((value) => DropdownMenuItem(value: value, child: Text(value))),
          ],
          onChanged: (value) => setState(() => category = value ?? 'All categories'),
        ),
        const SizedBox(height: 9),
        DropdownButtonFormField<String>(
          value: frequency,
          decoration: const InputDecoration(labelText: 'Payment frequency'),
          items: [
            const DropdownMenuItem(value: 'All frequencies', child: Text('All frequencies')),
            ...frequencies.map((value) => DropdownMenuItem(value: value, child: Text(value))),
          ],
          onChanged: (value) => setState(() => frequency = value ?? 'All frequencies'),
        ),
        const SizedBox(height: 11),
        Text(visible.length.toString() + ' Ekubs', style: const TextStyle(color: muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        if (loading)
          const Center(child: Padding(padding: EdgeInsets.all(25), child: CircularProgressIndicator()))
        else if (error != null)
          _Retry(text: error!, onRetry: _load)
        else if (visible.isEmpty)
          const _Empty(text: 'No Ekubs match your filters. Change the search or pull down to refresh.')
        else
          ...visible.map((row) {
            final item = _map(row);
            final canJoin = item['joined'] != true && item['status'] == 'open' && item['is_full'] != true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EkubCard(
                item: item,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EkubDetails(api: widget.api, id: _int(item['id'])))),
                onAction: canJoin ? () => _join(item) : null,
                actionLabel: item['joined'] == true ? 'Joined' : item['is_full'] == true ? 'Full' : 'Join Ekub',
                actionIcon: item['joined'] == true ? Icons.check_circle_outline : Icons.person_add_alt_1,
                busy: joining,
              ),
            );
          }),
      ]),
    );
  }
}

class MyEkubsView extends StatefulWidget {
  const MyEkubsView({super.key, required this.api, required this.onShowStatus, required this.onBrowse});
  final ApiClient api;
  final VoidCallback onShowStatus;
  final VoidCallback onBrowse;

  @override
  State<MyEkubsView> createState() => _MyEkubsViewState();
}

class _MyEkubsViewState extends State<MyEkubsView> {
  bool loading = true;
  String? error;
  List<dynamic> rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      rows = (await widget.api.get('/my/ekubs'))['data'] as List? ?? [];
    } on ApiException catch (exception) {
      error = exception.message;
    }
    if (mounted) setState(() => loading = false);
  }

  final Set<int> leavingIds = {};

  Future<void> _leave(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this Ekub?'),
        content: Text('You will leave ' + (item['name'] ?? 'this Ekub').toString() + '.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
        ],
      ),
    );
    if (confirmed != true) return;
    final id = _int(item['id']);
    setState(() => leavingIds.add(id));
    try {
      final response = await widget.api.delete('/ekubs/' + id.toString() + '/leave');
      if (mounted) _snack(context, response['message']?.toString() ?? 'You left the Ekub.');
      await _load();
    } on ApiException catch (exception) {
      if (mounted) _snack(context, exception.message);
    } finally {
      leavingIds.remove(id);
      if (mounted) setState(() {});
    }
  }
  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text('My Ekubs', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Open a group for details or go straight to your payment schedule.', style: TextStyle(color: muted)),
          const SizedBox(height: 13),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(25), child: CircularProgressIndicator()))
          else if (error != null)
            _Retry(text: error!, onRetry: _load)
          else if (rows.isEmpty)
            Column(children: [
              const _Empty(text: 'You have not joined an Ekub yet. Explore available Ekubs to get started.'),
              const SizedBox(height: 8),
              FilledButton.icon(onPressed: widget.onBrowse, icon: const Icon(Icons.explore), label: const Text('Browse Ekubs')),
            ])
          else
            ...rows.map((row) {
              final item = _map(row);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EkubCard(
                  item: item,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EkubDetails(api: widget.api, id: _int(item['id'])))),
                  onAction: widget.onShowStatus,
                  actionLabel: 'Payments',
                  actionIcon: Icons.receipt_long_outlined,
                  onExtraAction: item['status'] == 'open' && !leavingIds.contains(_int(item['id'])) ? () => _leave(item) : null,
                  extraActionLabel: leavingIds.contains(_int(item['id'])) ? 'Wait' : 'Leave',
                  extraActionIcon: Icons.logout,
                  busy: leavingIds.contains(_int(item['id'])),
                ),
              );
            }),
        ]),
      );
}
class EkubDetails extends StatefulWidget {
  const EkubDetails({super.key, required this.api, required this.id});
  final ApiClient api;
  final int id;
  @override
  State<EkubDetails> createState() => _EkubDetailsState();
}

class _EkubDetailsState extends State<EkubDetails> {
  Map<String, dynamic>? result;
  bool loading = true;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      result = await widget.api.get('/ekubs/' + widget.id.toString());
    } on ApiException catch (exception) {
      error = exception.message;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _join() async {
    final item = _map(result?['ekub']);
    setState(() { busy = true; error = null; });
    final joined = await _joinEkub(context, widget.api, item);
    if (joined) await _load();
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (result == null) return Scaffold(appBar: AppBar(), body: _Retry(text: error ?? 'Could not load Ekub.', onRetry: _load));
    final item = _map(result!['ekub']);
    final membership = _map(result!['membership']);
    final joined = membership.isNotEmpty;
    final images = item['images'] as List? ?? [];
    final members = result!['members'] as List? ?? [];
    final winners = result!['winners'] as List? ?? [];
    final canJoin = !joined && item['is_full'] != true && item['status'] == 'open';

    return Scaffold(
      appBar: AppBar(title: const Text('Ekub details')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (images.isEmpty)
          const _ImageBox(height: 180)
        else
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => SizedBox(
                width: MediaQuery.sizeOf(context).width - 32,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Image.network(
                    images[index].toString(),
                    height: 190,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _ImageBox(height: 180),
                  ),
                ),
              ),
            ),
          ),
        if (images.length > 1) ...[
          const SizedBox(height: 6),
          Text('Swipe to view all ' + images.length.toString() + ' photos', style: const TextStyle(color: muted, fontSize: 12)),
        ],
        const SizedBox(height: 15),
        Text(item['name']?.toString() ?? 'Ekub', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text((item['category'] ?? '').toString() + ' · ' + (item['frequency'] ?? '').toString(), style: const TextStyle(color: muted)),
        const SizedBox(height: 15),
        Wrap(spacing: 9, runSpacing: 9, children: [
          _Info(label: 'Contribution', value: _money(item['base_amount'])),
          _Info(label: 'Periods', value: _int(item['duration']).toString()),
          _Info(label: 'Members', value: _int(item['member_count']).toString()),
          _Info(label: 'Shares filled', value: _num(item['used_capacity']).toStringAsFixed(2) + '/' + _int(item['capacity']).toString()),
          _Info(label: 'Service fee', value: '2%'),
          _Info(label: 'Potential payout', value: _money(result!['potential_net_payout'])),
        ]),
        const SizedBox(height: 11),
        const _Message(text: 'The potential payout is calculated after the 2% service fee. Actual payments must be confirmed by the site.', isError: false),
        if (joined) ...[
          const SizedBox(height: 10),
          _Message(
            text: 'Your share: ' + (membership['share_type'] ?? '').toString().toUpperCase() +
                ' · contribution per period: ' + _money(membership['contribution_amount']),
            isError: false,
          ),
        ],
        if (error != null) ...[const SizedBox(height: 12), _Message(text: error!, isError: true)],
        const SizedBox(height: 15),
        if (joined)
          const FilledButton(onPressed: null, child: Text('You joined this Ekub'))
        else if (canJoin)
          FilledButton.icon(
            onPressed: busy ? null : _join,
            icon: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.person_add_alt_1),
            label: const Text('Join Ekub'),
          )
        else
          _Message(
            text: item['is_full'] == true ? 'This Ekub is full.' : 'This Ekub is no longer accepting members.',
            isError: false,
          ),
        const SizedBox(height: 20),
        Text('Current members', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (members.isEmpty)
          const _Empty(text: 'No members have joined yet.')
        else
          Card(
            child: Column(
              children: members.map((row) {
                final member = _map(row);
                final name = ((member['first_name'] ?? '').toString() + ' ' + (member['last_name'] ?? '').toString()).trim();
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF153329),
                    child: Text(name.isEmpty ? 'M' : name[0].toUpperCase()),
                  ),
                  title: Text(name.isEmpty ? 'Member' : name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('@' + (member['username'] ?? '').toString() + ' · ' + (member['share_type'] ?? '').toString() + ' share'),
                  trailing: Text(_money(member['contribution_amount']), style: const TextStyle(fontWeight: FontWeight.w700)),
                );
              }).toList(),
            ),
          ),
        if (winners.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Winners', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...winners.map((row) {
            final winner = _map(row);
            return Card(
              child: ListTile(
                leading: const Icon(Icons.emoji_events_outlined, color: green),
                title: Text('Period ' + winner['period_no'].toString()),
                subtitle: Text('@' + (winner['username'] ?? '').toString()),
                trailing: Text(_money(winner['net_amount']), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            );
          }),
        ],
      ]),
    );
  }
}
class StatusView extends StatefulWidget {
  const StatusView({super.key, required this.api});
  final ApiClient api;
  @override
  State<StatusView> createState() => _StatusViewState();
}

class _StatusViewState extends State<StatusView> with WidgetsBindingObserver {
  bool loading = true;
  bool busy = false;
  String? error;
  List<dynamic> rows = [];
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _load(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) _load(); }
  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      rows = (await widget.api.get('/my/status'))['data'] as List? ?? [];
    } on ApiException catch (exception) {
      error = exception.message;
    }
    if (mounted) setState(() => loading = false);
  }
  Future<void> _pay(int ekubId, int period) async {
    setState(() { busy = true; error = null; });
    try {
      final response = await widget.api.post('/payments/$ekubId/$period/telebirr');
      final uri = Uri.tryParse(response['checkout_url']?.toString() ?? '');
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const ApiException('Could not open Telebirr checkout.');
      }
      if (mounted) _snack(context, 'Checkout opened. Payment remains pending until merchant settlement is confirmed.');
    } on ApiException catch (exception) {
      setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text('Payment status', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('View confirmed contributions and remaining balances.', style: TextStyle(color: muted)),
          const SizedBox(height: 13),
          if (error != null) _Message(text: error!, isError: true),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(25), child: CircularProgressIndicator()))
          else if (rows.isEmpty)
            const _Empty(text: 'Join an Ekub to see your contribution schedule.')
          else
            ...rows.map((row) {
              final group = _map(row);
              final ekub = _map(group['ekub']);
              final periods = group['periods'] as List? ?? [];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(ekub['name']?.toString() ?? 'Ekub', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const Divider(height: 22),
                      ...periods.map((value) {
                        final period = _map(value);
                        final payments = period['payments'] as List? ?? [];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFF153329), borderRadius: BorderRadius.circular(14)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Row(children: [
                              Expanded(child: Text('Period ' + period['period_no'].toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
                              Text(_periodLabel(period), style: const TextStyle(color: green, fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 6),
                            Text('Due ' + _money(period['required']) + ' · paid ' + _money(period['paid']), style: const TextStyle(color: muted)),
                            if (_num(period['pending']) > 0)
                              Text('Pending review ' + _money(period['pending']), style: const TextStyle(color: Color(0xFFFFC66D))),
                            ...payments.map((value) {
                              final payment = _map(value);
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(
                                    (payment['method'] ?? '').toString() + ' · ' + _money(payment['amount']) + ' · ' + (payment['verification_status'] ?? payment['status']).toString(),
                                    style: const TextStyle(fontSize: 12, color: muted),
                                  ),
                                  if ((payment['transaction_no'] ?? '').toString().isNotEmpty)
                                    Text('Transaction ID: ' + payment['transaction_no'].toString(), style: const TextStyle(fontSize: 11, color: muted)),
                                  if ((payment['verification_message'] ?? '').toString().isNotEmpty)
                                    Text(payment['verification_message'].toString(), style: const TextStyle(fontSize: 11, color: muted)),
                                ]),
                              );
                            }),
                            if (period['can_pay'] == true) ...[
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: busy ? null : () => _pay(_int(ekub['id']), _int(period['period_no'])),
                                icon: const Icon(Icons.account_balance_wallet_outlined),
                                label: Text('Pay with Telebirr · ' + _money(period['available_to_pay'])),
                              ),
                            ],
                            if (period['winner'] is Map)
                              Text('Winner @' + (_map(period['winner'])['username'] ?? '').toString(), style: const TextStyle(color: green)),
                          ]),
                        );
                      }),
                    ]),
                  ),
                ),
              );
            }),
        ]),
      );
}

class ProfileView extends StatefulWidget {
  const ProfileView({super.key, required this.api, required this.user, required this.onSignOut});
  final ApiClient api;
  final Map<String, dynamic> user;
  final Future<void> Function() onSignOut;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late Map<String, dynamic> profile;
  @override
  void initState() { super.initState(); profile = widget.user; }
  Future<void> _refresh() async {
    try { profile = _map((await widget.api.get('/me'))['user']); if (mounted) setState(() {}); } catch (_) {}
  }
  Future<void> _open(BuildContext context, String feature) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProfileFeaturePage(api: widget.api, user: profile, feature: feature, onSignOut: widget.onSignOut)));
    if (mounted) await _refresh();
  }
  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, String feature) => ListTile(
    leading: Icon(icon, color: green),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle, style: const TextStyle(color: muted)),
    trailing: const Icon(Icons.chevron_right, color: muted),
    onTap: () => _open(context, feature),
  );
  @override
  Widget build(BuildContext context) {
    final fullName = ((profile['first_name'] ?? '').toString() + ' ' + (profile['last_name'] ?? '').toString()).trim();
    final kyc = (profile['kyc_status'] ?? 'not_submitted').toString();
    final picture = profile['profile_picture_url']?.toString();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Profile', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 13),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
        CircleAvatar(radius: 34, backgroundColor: const Color(0xFF153329), backgroundImage: picture == null || picture.isEmpty ? null : NetworkImage(picture),
          child: picture == null || picture.isEmpty ? Text(fullName.isEmpty ? 'M' : fullName[0].toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)) : null),
        const SizedBox(height: 10),
        Text(fullName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        Text('@' + (profile['username'] ?? '').toString(), style: const TextStyle(color: muted)),
        Text((profile['phone'] ?? '').toString(), style: const TextStyle(color: muted)),
        if (profile['email'] != null) Text(profile['email'].toString(), style: const TextStyle(color: muted)),
      ]))),
      const SizedBox(height: 12),
      Card(child: ListTile(
        leading: const Icon(Icons.edit_outlined, color: green),
        title: const Text('Edit profile'),
        subtitle: const Text('Update your personal details and profile picture', style: TextStyle(color: muted)),
        trailing: const Icon(Icons.chevron_right, color: muted), onTap: () => _open(context, 'profile_details'),
      )),
      const SizedBox(height: 12),
      Card(child: ListTile(
        leading: Icon(kyc == 'approved' ? Icons.verified_user : Icons.shield_outlined, color: kyc == 'approved' ? green : const Color(0xFFFFC66D)),
        title: const Text('Identity verification'), subtitle: Text(kyc.replaceAll('_', ' ').toUpperCase()),
        trailing: const Icon(Icons.chevron_right, color: muted), onTap: () => _open(context, 'kyc'),
      )),
      const SizedBox(height: 12),
      Text('Your account', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      Card(child: Column(children: [
        _tile(context, Icons.account_balance_wallet_outlined, 'Payment methods', 'Manage saved payout accounts', 'payment_methods'),
        const Divider(height: 1, indent: 56),
        _tile(context, Icons.manage_accounts_outlined, 'Account settings', 'Change password or close your account', 'settings'),
        const Divider(height: 1, indent: 56),
        _tile(context, Icons.phonelink_lock_outlined, 'Two-step verification', 'Email codes and authenticator app', 'security'),
        const Divider(height: 1, indent: 56),
        _tile(context, Icons.add_business_outlined, 'Apply to create an Ekub', 'Send and track your application', 'applications'),
        const Divider(height: 1, indent: 56),
        _tile(context, Icons.task_alt_outlined, 'Finished Ekubs', 'Review completed groups and winners', 'finished'),
      ])),
      const SizedBox(height: 12),
      Text('Mekenet Ekub', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      Card(child: Column(children: [
        _tile(context, Icons.info_outline, 'About', 'How the platform works', 'about'),
        const Divider(height: 1, indent: 56),
        _tile(context, Icons.privacy_tip_outlined, 'Privacy policy', 'Your information and choices', 'privacy'),
        const Divider(height: 1, indent: 56),
        _tile(context, Icons.gavel_outlined, 'Terms of service', 'Platform rules and fees', 'terms'),
        const Divider(height: 1, indent: 56),
        _tile(context, Icons.support_agent_outlined, 'Contact support', 'Help with your account or payments', 'contact'),
      ])),
      const SizedBox(height: 16),
      OutlinedButton.icon(onPressed: () => widget.onSignOut(), icon: const Icon(Icons.logout), label: const Text('Sign out')),
    ]);
  }
}

class ProfileFeaturePage extends StatefulWidget {
  const ProfileFeaturePage({super.key, required this.api, required this.user, required this.feature, required this.onSignOut});
  final ApiClient api;
  final Map<String, dynamic> user;
  final String feature;
  final Future<void> Function() onSignOut;
  @override
  State<ProfileFeaturePage> createState() => _ProfileFeaturePageState();
}

class _ProfileFeaturePageState extends State<ProfileFeaturePage> {
  final form = GlobalKey<FormState>();
  final picker = ImagePicker();
  final fields = <String, TextEditingController>{};
  Map<String, dynamic> result = {};
  List<dynamic> rows = [];
  List<String> banks = [], categories = [], frequencies = [];
  String? bank, category, frequency, idType = 'National ID', gender = 'Male', reason = 'I no longer need the service';
  XFile? photo, front, back, video, profilePicture;
  bool loading = true, busy = false, emailCodeSent = false;
  String? secret;

  TextEditingController field(String key) => fields.putIfAbsent(key, () => TextEditingController());
  @override
  void initState() {
    super.initState();
    field('full_name').text = ((widget.user['first_name'] ?? '').toString() + ' ' + (widget.user['last_name'] ?? '').toString()).trim();
    field('first_name').text = (widget.user['first_name'] ?? '').toString();
    field('last_name').text = (widget.user['last_name'] ?? '').toString();
    field('username').text = (widget.user['username'] ?? '').toString();
    field('phone').text = (widget.user['phone'] ?? '').toString();
    field('email').text = (widget.user['email'] ?? '').toString();
    field('duration').text = '12';
    _load();
  }
  @override
  void dispose() { for (final c in fields.values) { c.dispose(); } super.dispose(); }

  Future<void> _load() async {
    setState(() { loading = true; });
    try {
      switch (widget.feature) {
        case 'payment_methods':
          result = await widget.api.get('/profile/payment-methods');
          rows = result['data'] as List? ?? [];
          banks = (result['banks'] as List? ?? []).map((e) => e.toString()).toList();
          if (bank == null && banks.isNotEmpty) bank = banks.first;
        case 'applications':
          result = await widget.api.get('/profile/applications');
          rows = result['data'] as List? ?? [];
          categories = (result['categories'] as List? ?? []).map((e) => e.toString()).toList();
          frequencies = (result['frequencies'] as List? ?? []).map((e) => e.toString()).toList();
          category ??= categories.isEmpty ? null : categories.first;
          frequency ??= frequencies.isEmpty ? null : frequencies.first;
        case 'finished':
          rows = (await widget.api.get('/profile/finished-ekubs'))['data'] as List? ?? [];
        case 'kyc':
          result = await widget.api.get('/profile/kyc');
          final verification = _map(result['verification']);
          if (verification.isNotEmpty) {
            field('full_name').text = (verification['full_name'] ?? field('full_name').text).toString();
            field('dob').text = (verification['dob'] ?? '').toString();
            field('id_number').text = (verification['id_number'] ?? '').toString();
            gender = (verification['gender'] ?? gender).toString();
            idType = (verification['id_type'] ?? idType).toString();
          }
        case 'security':
          result = await widget.api.get('/profile/security');
      }
    } on ApiException catch (e) { result['error'] = e.message; }
    if (mounted) setState(() => loading = false);
  }

  Future<bool> _post(String path, Map<String, dynamic> body, {bool reload = true}) async {
    setState(() => busy = true);
    try {
      final response = await widget.api.post(path, body: body);
      if (mounted) _snack(context, response['message']?.toString() ?? 'Saved.');
      if (reload) await _load();
      return true;
    } on ApiException catch (e) { if (mounted) _snack(context, e.message); return false; }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _paymentAdd() async {
    if (!form.currentState!.validate()) return;
    final saved = await _post('/profile/payment-methods', {'bank_name': bank, 'account_name': field('account_name').text.trim(), 'account_number': field('account_number').text.trim()});
    if (saved) { field('account_name').clear(); field('account_number').clear(); }
  }
  Future<void> _deletePayment(int id) async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Remove payout account?'), content: const Text('This account will be removed from your profile.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove'))],
    ));
    if (ok == true) { setState(() => busy = true); try { await widget.api.delete('/profile/payment-methods/$id'); await _load(); } on ApiException catch (e) { if (mounted) _snack(context, e.message); } finally { if (mounted) setState(() => busy = false); } }
  }
  Future<void> _application() async {
    if (!form.currentState!.validate()) return;
    final sent = await _post('/profile/applications', {'name': field('name').text.trim(), 'category': category, 'frequency': frequency, 'base_amount': double.tryParse(field('amount').text) ?? 0, 'duration': int.tryParse(field('duration').text) ?? 0, 'note': field('note').text.trim()});
    if (sent) { field('name').clear(); field('amount').clear(); field('note').clear(); }
  }
  Future<void> _pick(String key) async {
    final file = key == 'video'
      ? await picker.pickVideo(source: ImageSource.gallery)
      : await picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (file == null) return;
    setState(() {
      if (key == 'photo') photo = file;
      if (key == 'front') front = file;
      if (key == 'back') back = file;
      if (key == 'video') video = file;
      if (key == 'profile_picture') profilePicture = file;
    });
  }
  Future<void> _saveProfile() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      final response = await widget.api.post('/profile', body: {
        'first_name': field('first_name').text.trim(),
        'last_name': field('last_name').text.trim(),
        'username': field('username').text.trim(),
        'phone': field('phone').text.trim(),
        'email': field('email').text.trim(),
      });
      if (mounted) {
        _snack(context, response['message']?.toString() ?? 'Profile updated.');
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) { if (mounted) _snack(context, e.message); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _saveProfilePicture() async {
    if (profilePicture == null) { _snack(context, 'Choose a profile picture first.'); return; }
    setState(() => busy = true);
    try {
      final response = await widget.api.postFiles('/profile/picture', fields: const {}, files: {'profile_picture': profilePicture!.path});
      if (mounted) {
        _snack(context, response['message']?.toString() ?? 'Profile picture updated.');
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) { if (mounted) _snack(context, e.message); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _submitKyc() async {
    if (!form.currentState!.validate()) return;
    if (photo == null || front == null || (idType == 'National ID' && back == null) || video == null) { _snack(context, 'Select your personal photo, ID images, and video agreement.'); return; }
    setState(() => busy = true);
    try {
      final r = await widget.api.postFiles('/profile/kyc', fields: {'full_name': field('full_name').text.trim(), 'dob': field('dob').text.trim(), 'gender': gender!, 'id_type': idType!, 'id_number': field('id_number').text.trim()}, files: {
        'personal_photo': photo!.path, 'id_front': front!.path, if (idType == 'National ID') 'id_back': back!.path, 'video_agreement': video!.path,
      });
      if (mounted) _snack(context, r['message']?.toString() ?? 'Submitted for review.');
      result['status'] = 'pending';
      setState(() { photo = null; front = null; back = null; video = null; });
    } on ApiException catch (e) { if (mounted) _snack(context, e.message); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _security(String action, [Map<String, dynamic>? body]) async {
    setState(() => busy = true);
    try {
      final r = await widget.api.post('/profile/security/$action', body: body);
      if (mounted) _snack(context, r['message']?.toString() ?? 'Updated.');
      if (action == 'start-authenticator') { secret = r['secret']?.toString(); await Clipboard.setData(ClipboardData(text: secret ?? '')); }
      if (action == 'send-email-code') emailCodeSent = true;
      if (action == 'verify-email' || action == 'verify-authenticator' || action == 'disable') { secret = null; emailCodeSent = false; field('code').clear(); result = await widget.api.get('/profile/security'); }
    } on ApiException catch (e) { if (mounted) _snack(context, e.message); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _deleteAccount() async {
    if (field('delete_password').text.isEmpty) { _snack(context, 'Enter your password to confirm account deletion.'); return; }
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Delete your account?'),
      content: const Text('This cannot be undone. You cannot delete while you are in a running Ekub.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))],
    ));
    if (ok != true) return;
    setState(() => busy = true);
    try { await widget.api.post('/profile/account/delete', body: {'password': field('delete_password').text, 'reason': reason, 'details': field('delete_details').text}); await widget.onSignOut(); if (mounted) Navigator.of(context).popUntil((r) => r.isFirst); }
    on ApiException catch (e) { if (mounted) _snack(context, e.message); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Widget _fileTile(String title, XFile? file, String key) => Card(child: ListTile(
    leading: Icon(file == null ? (key == 'video' ? Icons.videocam_outlined : Icons.image_outlined) : Icons.check_circle, color: file == null ? muted : green),
    title: Text(title), subtitle: Text(file?.name ?? 'Choose from your phone'), trailing: const Icon(Icons.upload_file), onTap: () => _pick(key),
  ));
  Widget _errorOrEmpty(String message) => Center(child: _Message(text: message, isError: true));

  Widget _body(BuildContext context) {
    if (result['error'] != null) return _errorOrEmpty(result['error'].toString());
    switch (widget.feature) {
      case 'profile_details':
        final locked = widget.user['kyc_status'] == 'approved';
        return ListView(padding: const EdgeInsets.all(16), children: [
          if (locked) const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('Your personal information is locked after identity verification. You can still update your profile picture.'))),
          Form(key: form, child: Column(children: [
            TextFormField(controller: field('first_name'), readOnly: locked, decoration: const InputDecoration(labelText: 'First name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your first name.' : null),
            const SizedBox(height: 8),
            TextFormField(controller: field('last_name'), readOnly: locked, decoration: const InputDecoration(labelText: 'Last name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your last name.' : null),
            const SizedBox(height: 8),
            TextFormField(controller: field('username'), readOnly: locked, decoration: const InputDecoration(labelText: 'Username'), validator: (v) => (v == null || !RegExp(r'^[A-Za-z0-9_.]{3,30}$').hasMatch(v.trim())) ? 'Use 3–30 letters, numbers, dots, or underscores.' : null),
            const SizedBox(height: 8),
            TextFormField(controller: field('phone'), readOnly: locked, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number'), validator: (v) => (v == null || v.replaceAll(RegExp(r'\D'), '').length < 9) ? 'Enter a valid Ethiopian phone number.' : null),
            const SizedBox(height: 8),
            TextFormField(controller: field('email'), readOnly: locked, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Gmail address (optional)'), validator: (v) => (v == null || v.trim().isEmpty || RegExp(r'^[A-Z0-9._%+-]+@gmail\.com$', caseSensitive: false).hasMatch(v.trim())) ? null : 'Enter a valid Gmail address.'),
            if (!locked) ...[const SizedBox(height: 12), FilledButton(onPressed: busy ? null : _saveProfile, child: const Text('Save profile'))],
          ])),
          const SizedBox(height: 18),
          _fileTile('Profile picture', profilePicture, 'profile_picture'),
          FilledButton(onPressed: busy ? null : _saveProfilePicture, child: const Text('Update profile picture')),
        ]);
      case 'payment_methods':
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Manage accounts for receiving payouts. Account numbers are masked after saving.', style: TextStyle(color: muted)),
          ...rows.map((e) { final r = _map(e); final id = _int(r['id']); return Card(child: ListTile(
            leading: const Icon(Icons.account_balance, color: green), title: Text(r['bank_name'].toString()), subtitle: Text((r['account_name'] ?? '').toString() + ' · ' + (r['account_number'] ?? '').toString()),
            trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'remove') { _deletePayment(id); } else { _post('/profile/payment-methods/$id/default', {}); } }, itemBuilder: (_) => [if (r['is_default'] != true) const PopupMenuItem(value: 'default', child: Text('Make default')), const PopupMenuItem(value: 'remove', child: Text('Remove'))]),
          ));}),
          const SizedBox(height: 14), const Text('Add account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Form(key: form, child: Column(children: [
            DropdownButtonFormField<String>(value: bank, decoration: const InputDecoration(labelText: 'Bank or wallet'), items: banks.map((b) => DropdownMenuItem(value: b, child: Text(b, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setState(() => bank = v)),
            const SizedBox(height: 8),
            TextFormField(controller: field('account_number'), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Account number'), validator: (v) => (v == null || v.replaceAll(RegExp(r'\D'), '').length < 6) ? 'Enter at least six digits.' : null),
            const SizedBox(height: 8),
            TextFormField(controller: field('account_name'), decoration: const InputDecoration(labelText: 'Account holder name'), validator: (v) => (v == null || v.trim().length < 3) ? 'Enter the account holder name.' : null),
            const SizedBox(height: 12), FilledButton(onPressed: busy ? null : _paymentAdd, child: const Text('Save account')),
          ])),
        ]);
      case 'applications':
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Apply to start an Ekub. An administrator will review your request.', style: TextStyle(color: muted)),
          Form(key: form, child: Column(children: [
            TextFormField(controller: field('name'), decoration: const InputDecoration(labelText: 'Ekub name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name.' : null),
            DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'Category'), items: categories.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => category = v)),
            DropdownButtonFormField<String>(value: frequency, decoration: const InputDecoration(labelText: 'Frequency'), items: frequencies.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => frequency = v)),
            TextFormField(controller: field('amount'), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Contribution per period (ETB)'), validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter an amount.' : null),
            TextFormField(controller: field('duration'), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number of periods'), validator: (v) {final n=int.tryParse(v ?? '');return n == null || n < 2 || n > 500 ? 'Enter 2 to 500 periods.' : null;}),
            TextFormField(controller: field('note'), maxLines: 3, decoration: const InputDecoration(labelText: 'Note (optional)')),
            const SizedBox(height: 10), FilledButton(onPressed: busy ? null : _application, child: const Text('Send application')),
          ])),
          const SizedBox(height: 18), const Text('Your applications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (rows.isEmpty) const _Empty(text: 'No applications submitted yet.'),
          ...rows.map((e) { final r = _map(e); return Card(child: ListTile(title: Text((r['name'] ?? '').toString()), subtitle: Text((r['category'] ?? '').toString() + ' · ' + (r['frequency'] ?? '').toString() + (r['rejection_reason'] == null ? '' : '\n' + r['rejection_reason'].toString())), trailing: Text((r['status'] ?? 'pending').toString().toUpperCase()))); }),
        ]);
      case 'finished':
        return rows.isEmpty ? const Center(child: _Empty(text: 'No finished Ekubs yet.')) : ListView(padding: const EdgeInsets.all(16), children: rows.map((e) {
          final r = _map(e); final winners = r['winners'] as List? ?? [];
          return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((r['name'] ?? '').toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text((r['category'] ?? '').toString() + ' · ' + (r['frequency'] ?? '').toString(), style: const TextStyle(color: muted)),
            Text(_money(r['base_amount']) + ' ETB · ' + (r['duration'] ?? '').toString() + ' periods · ' + (r['member_count'] ?? '').toString() + ' members', style: const TextStyle(color: muted)),
            ...winners.map((w) { final win = _map(w); return Text('Period ' + (win['period_no'] ?? '').toString() + ': @' + (win['username'] ?? '').toString() + ' · ' + _money(win['net_amount']) + ' ETB'); }),
          ])));
        }).toList());
      case 'kyc':
        final status = (result['status'] ?? 'not_submitted').toString();
        final verification = _map(result['verification']);
        return ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: ListTile(leading: Icon(status == 'approved' ? Icons.verified : Icons.hourglass_top, color: status == 'approved' ? green : const Color(0xFFFFC66D)), title: Text(status.replaceAll('_', ' ').toUpperCase()), subtitle: Text((verification['rejection_reason'] ?? 'Send your identity information for review.').toString()))),
          if (status != 'approved') Form(key: form, child: Column(children: [
            TextFormField(controller: field('full_name'), decoration: const InputDecoration(labelText: 'Full legal name'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name.' : null),
            TextFormField(controller: field('dob'), decoration: const InputDecoration(labelText: 'Date of birth (YYYY-MM-DD)'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your date of birth.' : null),
            DropdownButtonFormField<String>(value: gender, decoration: const InputDecoration(labelText: 'Gender'), items: const ['Male','Female','Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => gender = v ?? gender)),
            DropdownButtonFormField<String>(value: idType, decoration: const InputDecoration(labelText: 'ID type'), items: const ['National ID','Passport'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => idType = v ?? idType)),
            TextFormField(controller: field('id_number'), decoration: const InputDecoration(labelText: 'ID number'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your ID number.' : null),
            _fileTile('Personal photo', photo, 'photo'), _fileTile(idType == 'Passport' ? 'Passport image' : 'ID front image', front, 'front'),
            if (idType == 'National ID') _fileTile('ID back image', back, 'back'),
            _fileTile('Video agreement', video, 'video'),
            const Padding(padding: EdgeInsets.all(8), child: Text('Your documents are sent securely for identity review.', style: TextStyle(color: muted))),
            FilledButton(onPressed: busy ? null : _submitKyc, child: Text(busy ? 'Submitting…' : 'Submit for review')),
          ])),
        ]);
      case 'settings':
        return ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: ListTile(title: Text('@' + (widget.user['username'] ?? '').toString()), subtitle: Text((widget.user['phone'] ?? '').toString() + ' · ' + (widget.user['email'] ?? 'No email').toString()))),
          const SizedBox(height: 12), const Text('Change password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Form(key: form, child: Column(children: [
            TextFormField(controller: field('current_password'), obscureText: true, decoration: const InputDecoration(labelText: 'Current password'), validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password.' : null),
            TextFormField(controller: field('new_password'), obscureText: true, decoration: const InputDecoration(labelText: 'New password'), validator: (v) => (v == null || v.length < 8 || !RegExp(r'[A-Z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v) || !RegExp(r'[^A-Za-z0-9]').hasMatch(v)) ? 'Use 8+ characters with an uppercase letter, a number, and a symbol.' : null),
            TextFormField(controller: field('new_password_confirmation'), obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password'), validator: (v) => v != field('new_password').text ? 'Passwords do not match.' : null),
            FilledButton(onPressed: busy ? null : () async { if (form.currentState!.validate()) { final changed = await _post('/profile/password', {'current_password': field('current_password').text, 'new_password': field('new_password').text, 'new_password_confirmation': field('new_password_confirmation').text}, reload: false); if (changed) { field('current_password').clear(); field('new_password').clear(); field('new_password_confirmation').clear(); } } }, child: const Text('Update password')),
          ])),
          const SizedBox(height: 24), const Text('Delete account', style: TextStyle(fontSize: 18, color: Colors.redAccent, fontWeight: FontWeight.w800)),
          const Text('You cannot delete your account while part of a running Ekub. This action cannot be undone.', style: TextStyle(color: muted)),
          DropdownButtonFormField<String>(value: reason, decoration: const InputDecoration(labelText: 'Reason'), items: const ['I no longer need the service','I have privacy concerns','I created a second account','I am not satisfied with the service','I had a problem with a payment','Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => reason = v)),
          if (reason == 'Other') TextField(controller: field('delete_details'), decoration: const InputDecoration(labelText: 'Explain')),
          TextField(controller: field('delete_password'), obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          OutlinedButton(onPressed: busy ? null : _deleteAccount, child: const Text('Delete my account')),
        ]);
      case 'security':
        return ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: ListTile(leading: Icon(result['enabled'] == true ? Icons.verified_user : Icons.shield_outlined, color: green), title: Text(result['enabled'] == true ? 'Protection enabled' : 'Protection is off'), subtitle: Text('Email: ' + (result['email_hint'] ?? 'not available').toString()))),
          const SizedBox(height: 12), const Text('Email one-time code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (emailCodeSent) TextField(controller: field('code'), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Six-digit email code')),
          FilledButton(onPressed: busy ? null : emailCodeSent ? () => _security('verify-email', {'code': field('code').text.trim()}) : () => _security('send-email-code'), child: Text(emailCodeSent ? 'Verify and enable email OTP' : 'Send email code')),
          const SizedBox(height: 16), const Text('Authenticator app', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Text('Use Google Authenticator, Microsoft Authenticator, or another TOTP app.', style: TextStyle(color: muted)),
          if (secret != null) ...[
            const Text('Secret copied. Add this key manually in your authenticator app.'),
            SelectableText(secret!, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.4)),
            TextField(controller: field('code'), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Authenticator code')),
            FilledButton(onPressed: busy ? null : () => _security('verify-authenticator', {'code': field('code').text.trim()}), child: const Text('Verify authenticator')),
          ] else FilledButton.tonal(onPressed: busy ? null : () => _security('start-authenticator'), child: const Text('Set up authenticator')),
          if (result['enabled'] == true) OutlinedButton(onPressed: busy ? null : () async {
            final p = TextEditingController();
            final value = await showDialog<String>(context: context, builder: (c) => AlertDialog(title: const Text('Turn off two-step verification?'), content: TextField(controller: p, obscureText: true, decoration: const InputDecoration(labelText: 'Password')), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, p.text), child: const Text('Turn off'))]));
            p.dispose(); if (value != null && value.isNotEmpty) await _security('disable', {'password': value});
          }, child: const Text('Turn off two-step verification')),
        ]);
      default:
        return _infoBody(context);
    }
  }

  Widget _infoBody(BuildContext context) {
    final data = switch (widget.feature) {
      'about' => const [('Saving together. Growing together.', 'Mekenet Ekub brings the familiar tradition of እቁብ into an organized digital experience, helping members explore groups and follow their participation.'), ('How it works', 'Review each group’s category, schedule, contribution, duration and capacity. KYC approval is required before joining.'), ('Payout fee', 'The stated service fee is 2% of the collected pool. The winner receives 98%, subject to the group rules.')],
      'privacy' => const [('Information collected', 'Your account details, identity documents, payment records and saved payout accounts.'), ('How it is used', 'To verify identity, manage Ekub groups, confirm contributions, send reminders and security codes, pay winners and prevent abuse.'), ('Who can see it', 'Authorised administrators and partners with matching permissions can review identity and payment information. Members cannot see other members’ documents or bank details.'), ('Retention and deletion', 'You may request account deletion when you are not part of a running Ekub. Some accounting records may be retained as described in the site policy.')],
      'terms' => const [('Service fee', 'A 2% fee is deducted from the approved gross pool when a member wins a period. The winner receives 98%.'), ('Late payment', 'Late payments may receive a penalty according to the Ekub configuration.'), ('Verification', 'KYC approval is required before joining active Ekubs. Check the contribution schedule before joining.')],
      _ => const [('Call support', '+251 951 180 317'), ('Email', 'mekenetsupport@gmail.com'), ('Working hours', 'Monday to Saturday, 12:00 AM–4:00 PM. Sunday closed.'), ('Account safety', 'Support will never ask for your password or authenticator code.')],
    };
    final title = switch (widget.feature) {'about' => 'About Mekenet Ekub', 'privacy' => 'Privacy policy', 'terms' => 'Terms of service', _ => 'Contact support'};
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (widget.feature == 'about') Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [green, blue]), borderRadius: BorderRadius.circular(20)), child: const Text('Build your future together.', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      ...data.map((entry) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(entry.$1, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), const SizedBox(height: 6),
        SelectableText(entry.$2, style: const TextStyle(color: muted, height: 1.4)),
        if (widget.feature == 'contact' && (entry.$1 == 'Call support' || entry.$1 == 'Email')) Align(alignment: Alignment.centerRight, child: IconButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: entry.$2)); if (context.mounted) _snack(context, 'Copied to clipboard.'); }, icon: const Icon(Icons.copy, color: green))),
      ])))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final titles = {'profile_details':'Edit profile','kyc':'Identity verification','payment_methods':'Payment methods','settings':'Account settings','security':'Two-step verification','applications':'Ekub applications','finished':'Finished Ekubs','about':'About','privacy':'Privacy policy','terms':'Terms of service','contact':'Contact support'};
    return Scaffold(appBar: AppBar(title: Text(titles[widget.feature] ?? 'Profile')), body: loading ? const Center(child: CircularProgressIndicator()) : _body(context));
  }
}
Future<bool> _joinEkub(BuildContext context, ApiClient api, Map<String, dynamic> item) async {
  final options = item['is_item'] == true ? ['full'] : ['full', 'half', 'quarter'];
  final share = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: panel,
    builder: (context) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.all(16), child: Text('Choose your share', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
        ...options.map((value) => ListTile(
              leading: const Icon(Icons.check_circle_outline, color: green),
              title: Text(value.toUpperCase() + ' share'),
              subtitle: Text(value == 'full' ? 'Full contribution' : value == 'half' ? 'Half contribution' : 'Quarter contribution'),
              onTap: () => Navigator.pop(context, value),
            )),
      ]),
    ),
  );
  if (share == null || !context.mounted) return false;
  try {
    await api.post('/ekubs/' + _int(item['id']).toString() + '/join', body: {'share_type': share});
    if (context.mounted) _snack(context, 'You joined ' + (item['name'] ?? 'the Ekub').toString() + '.');
    return true;
  } on ApiException catch (exception) {
    if (context.mounted) _snack(context, exception.message);
    return false;
  }
}
class _EkubCard extends StatelessWidget {
  const _EkubCard({
    required this.item,
    required this.onTap,
    required this.onAction,
    required this.actionLabel,
    required this.actionIcon,
    this.onExtraAction,
    this.extraActionLabel,
    this.extraActionIcon,
    this.busy = false,
  });
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback? onAction;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onExtraAction;
  final String? extraActionLabel;
  final IconData? extraActionIcon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final images = item['images'] as List? ?? [];
    final capacity = _num(item['capacity']);
    final progress = capacity <= 0 ? 0.0 : (_num(item['used_capacity']) / capacity).clamp(0.0, 1.0).toDouble();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (images.isEmpty)
              const _ImageBox(height: 116)
            else
              Image.network(images.first.toString(), height: 142, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _ImageBox(height: 116)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 5),
              child: Row(children: [
                Expanded(child: Text(item['name']?.toString() ?? 'Ekub', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                if (item['joined'] == true) const _Pill(text: 'Joined'),
                if (item['status'] == 'started') const _Pill(text: 'Started'),
                if (item['status'] == 'open' && item['joined'] != true) const _Pill(text: 'Open'),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text((item['category'] ?? '').toString() + ' · ' + (item['frequency'] ?? '').toString(), style: const TextStyle(color: muted)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(children: [
                Expanded(child: _Metric(label: 'Contribution', value: _money(item['base_amount']))),
                Expanded(child: _Metric(label: 'Members', value: _int(item['member_count']).toString() + ' / ' + _int(item['capacity']).toString())),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: progress,
                  backgroundColor: const Color(0xFF263C33),
                  valueColor: const AlwaysStoppedAnimation<Color>(green),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              child: Text(
                item['is_full'] == true ? 'Full' : _num(item['slots_remaining']).toStringAsFixed(2) + ' shares available',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.info_outline, size: 16),
                label: const Text('Details', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : onAction,
                icon: busy && onExtraAction == null
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(actionIcon, size: 16),
                label: Text(actionLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            if (extraActionLabel != null) ...[
              const SizedBox(width: 7),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onExtraAction,
                  icon: extraActionIcon == null ? const SizedBox.shrink() : Icon(extraActionIcon, size: 15),
                  label: Text(extraActionLabel!, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}
class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) => const Row(children: [
        CircleAvatar(backgroundColor: green, child: Icon(Icons.savings_outlined, color: Colors.white)),
        SizedBox(width: 10),
        Text('Mekenet ', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
        Text('Ekub', style: TextStyle(fontSize: 23, color: blue, fontWeight: FontWeight.w900)),
      ]);
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ]);
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: (MediaQuery.sizeOf(context).width - 52) / 2,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: green.withAlpha(36), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(color: green, fontSize: 11, fontWeight: FontWeight.w800)),
      );
}

class _ImageBox extends StatelessWidget {
  const _ImageBox({this.height = 170});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        color: const Color(0xFF153329),
        alignment: Alignment.center,
        child: const Icon(Icons.savings_outlined, color: green, size: 44),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Column(children: [
            const Icon(Icons.inbox_outlined, color: green, size: 34),
            const SizedBox(height: 9),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: muted)),
          ]),
        ),
      );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.text, required this.onRetry});
  final String text;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 9),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
          ]),
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.isError});
  final String text;
  final bool isError;
  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFE55252) : green;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        border: Border.all(color: color.withAlpha(90)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: TextStyle(color: isError ? const Color(0xFFFFB7B7) : const Color(0xFFBFF1D2))),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry(key.toString(), item));
  return <String, dynamic>{};
}

double _num(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
int _int(dynamic value) => _num(value).toInt();
String _money(dynamic value) => _num(value).toStringAsFixed(2) + ' ETB';

String _periodLabel(Map<String, dynamic> value) {
  if (value['is_paid'] == true) return 'Paid';
  if (_num(value['pending']) > 0) return 'Pending review';
  if (value['can_pay'] == true) return 'Due now';
  if (value['is_current'] == true) return 'Current';
  return 'Upcoming';
}

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}


