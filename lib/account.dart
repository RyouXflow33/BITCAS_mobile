/// A signed-in driver. When there is no [Account] the app runs as a guest.
///
/// This is stored on the phone only. There is no sign-in server yet, so
/// [AppController.signIn] and [AppController.signUp] are the two places to
/// connect a real backend later.
class Account {
  const Account({required this.name, required this.email});

  final String name;
  final String email;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

String nameFromEmail(String email) {
  final local = email.split('@').first.trim();
  if (local.isEmpty) return 'Driver';
  final words = local.split(RegExp(r'[._-]+')).where((w) => w.isNotEmpty);
  return words.map((w) => w.substring(0, 1).toUpperCase() + w.substring(1)).join(' ');
}
