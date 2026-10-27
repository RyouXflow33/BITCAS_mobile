import 'package:flutter/material.dart';

import '../controller.dart';
import '../missions.dart';
import '../theme.dart';
import 'widgets.dart';

Future<void> showAccountSheet(BuildContext context) {
  AppScope.of(context).record(MissionEvent.accountOpen);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const AccountSheet(),
  );
}

enum _Mode { home, signIn, signUp }

class AccountSheet extends StatefulWidget {
  const AccountSheet({super.key});

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  _Mode _mode = _Mode.home;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _hidePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _go(_Mode mode) {
    setState(() {
      _mode = mode;
      _error = null;
    });
  }

  Future<void> _submit(AppController app) async {
    final email = _email.text.trim();
    final name = _name.text.trim();
    if (_mode == _Mode.signUp && name.isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Use a password with at least 6 characters.');
      return;
    }
    // Local only for now. Replace with a real call when a sign-in server exists.
    if (_mode == _Mode.signUp) {
      await app.signUp(name: name, email: email);
    } else {
      await app.signIn(email: email);
    }
    if (!mounted) return;
    _password.clear();
    _go(_Mode.home);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = Pal.of(context);
    final media = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(22, 10, 22, 22 + media.viewInsets.bottom + media.padding.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            if (_mode == _Mode.home) ..._home(context, app, p) else ..._form(context, app, p),
          ],
        ),
      ),
    );
  }

  List<Widget> _home(BuildContext context, AppController app, Pal p) {
    final account = app.account;
    return [
      const PageTitle('Account'),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: p.cardAlt, borderRadius: BorderRadius.circular(22)),
        child: Row(
          children: [
            Avatar(initials: account?.initials, size: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account?.name ?? 'Guest', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(account?.email ?? 'Using the app without an account', style: TextStyle(color: p.muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          _stat(p, 'POINTS', '${app.board.points}'),
          const SizedBox(width: 10),
          _stat(p, 'STREAK', '${app.streak} d'),
        ],
      ),
      const SizedBox(height: 16),
      if (account == null) ...[
        Text(
          'You can use every feature as a guest. An account adds your name to the app. Progress is kept on this phone for now.',
          style: TextStyle(color: p.muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 14),
        _primary(p, 'Sign in', () => _go(_Mode.signIn)),
        const SizedBox(height: 10),
        _secondary(p, 'Create account', () => _go(_Mode.signUp)),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: p.muted),
            child: const Text('Continue as guest'),
          ),
        ),
      ] else ...[
        _secondary(p, 'Sign out', () async {
          await app.signOut();
        }),
      ],
    ];
  }

  Widget _stat(Pal p, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: p.cardAlt, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: p.muted, fontSize: 10, letterSpacing: 0.6, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  List<Widget> _form(BuildContext context, AppController app, Pal p) {
    final signUp = _mode == _Mode.signUp;
    InputDecoration field(String label, IconData icon, {Widget? suffix}) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: p.cardAlt,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: p.ink, width: 1.5)),
      );
    }

    return [
      PageTitle(
        signUp ? 'Create account' : 'Sign in',
        trailing: RoundBtn(icon: Icons.chevron_left, filled: true, tooltip: 'Back', onTap: () => _go(_Mode.home)),
      ),
      const SizedBox(height: 16),
      if (signUp) ...[
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: field('Name', Icons.person_outline),
        ),
        const SizedBox(height: 10),
      ],
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        decoration: field('Email', Icons.mail_outline),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _password,
        obscureText: _hidePassword,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(app),
        decoration: field(
          'Password',
          Icons.lock_outline,
          suffix: IconButton(
            icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
            onPressed: () => setState(() => _hidePassword = !_hidePassword),
          ),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!, style: const TextStyle(color: Color(0xFFE5483B), fontSize: 12, fontWeight: FontWeight.w600)),
      ],
      const SizedBox(height: 16),
      _primary(p, signUp ? 'Create account' : 'Sign in', () => _submit(app)),
      const SizedBox(height: 6),
      Center(
        child: TextButton(
          onPressed: () => _go(signUp ? _Mode.signIn : _Mode.signUp),
          style: TextButton.styleFrom(foregroundColor: p.muted),
          child: Text(signUp ? 'I already have an account' : 'I need an account'),
        ),
      ),
    ];
  }

  Widget _primary(Pal p, String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: p.solid,
          foregroundColor: p.onSolid,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _secondary(Pal p, String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          side: BorderSide(color: p.ink, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// Initials in a lime circle, or a person icon for guests.
class Avatar extends StatelessWidget {
  const Avatar({super.key, this.initials, this.size = 44});

  final String? initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final signedIn = initials != null;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: signedIn ? p.lime : p.card, shape: BoxShape.circle),
      child: signedIn
          ? Text(initials!, style: TextStyle(color: p.onLime, fontWeight: FontWeight.w900, fontSize: size * 0.36))
          : Icon(Icons.person_outline, color: p.ink, size: size * 0.5),
    );
  }
}
