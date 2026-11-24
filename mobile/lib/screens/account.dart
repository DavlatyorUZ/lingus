import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/account_api.dart';
import '../ui/design.dart';
import '../ui/word_journey.dart';

Future<bool> requireAccount(BuildContext c) async {
  if (accountApi.signedIn) return true;
  await Navigator.push(
    c,
    MaterialPageRoute(builder: (_) => const AccountScreen()),
  );
  return accountApi.signedIn;
}

class AccountScreen extends StatefulWidget {
  final bool changePassword;
  const AccountScreen({super.key, this.changePassword = false});
  @override
  State<AccountScreen> createState() => _AccountState();
}

class _AccountState extends State<AccountScreen> {
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      code = TextEditingController(),
      old = TextEditingController();
  String mode = 'login';
  bool busy = false;
  String? message;
  int cooldown = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    if (widget.changePassword) {
      mode = accountApi.user?['hasPassword'] == false ? 'forgot' : 'change';
    }
    email.text = accountApi.user?['email'] as String? ?? '';
    name.text = store.name;
  }

  @override
  void dispose() {
    for (final c in [name, email, password, code, old]) {
      c.dispose();
    }
    timer?.cancel();
    super.dispose();
  }

  Future<void> run(Future<void> Function() fn) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void startCooldown() {
    timer?.cancel();
    cooldown = 60;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => cooldown--);
      if (cooldown <= 0) t.cancel();
    });
  }

  Future<void> send() async {
    if (mode == 'register' || mode == 'verify') {
      await accountApi.request(
        '/auth/register',
        method: 'POST',
        body: {
          'name': name.text.trim(),
          'email': email.text.trim(),
          'password': password.text,
        },
      );
      if (mounted) setState(() => mode = 'verify');
    } else {
      await accountApi.request(
        '/auth/password/request',
        method: 'POST',
        body: {'email': email.text.trim()},
      );
      if (mounted) setState(() => mode = 'reset');
    }
    if (mounted) {
      setState(() {
        message = 'Hisob mavjud bo‘lsa, kod emailingizga yuborildi.';
        startCooldown();
      });
    }
  }

  Future<void> submit() async {
    if (mode == 'login') {
      await accountApi.login(email.text.trim(), password.text);
      if (mounted) Navigator.pop(context);
    } else if (mode == 'register' || mode == 'forgot') {
      await send();
    } else if (mode == 'verify') {
      await accountApi.verify(email.text.trim(), code.text.trim());
      if (mounted) Navigator.pop(context);
    } else if (mode == 'reset') {
      await accountApi.request(
        '/auth/password/reset',
        method: 'POST',
        body: {
          'email': email.text.trim(),
          'code': code.text.trim(),
          'newPassword': password.text,
        },
      );
      await accountApi.accept(null);
      if (mounted) {
        setState(() {
          mode = 'login';
          message = 'Parol yangilandi. Yangi parol bilan kiring.';
        });
      }
    } else if (mode == 'change') {
      await accountApi.request(
        '/auth/password/change',
        method: 'POST',
        body: {'oldPassword': old.text, 'newPassword': password.text},
      );
      await accountApi.accept(null);
      if (mounted) {
        setState(() {
          mode = 'login';
          message = 'Parol yangilandi. Qayta kiring.';
        });
      }
    }
  }

  Future<void> google() async {
    final v = accountApi.verifier(), p = await accountApi.googleStart(v);
    if (!await launchUrl(
      Uri.parse(p['url'] as String),
      mode: LaunchMode.externalApplication,
    )) {
      throw const ApiFailure('Google oynasi ochilmadi.');
    }
    for (var i = 0; i < 180; i++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      if (await accountApi.googlePoll(p['ticket'] as String, v)) {
        if (mounted) Navigator.pop(context);
        return;
      }
    }
    throw const ApiFailure('Kirish vaqti tugadi. Qayta urinib ko‘ring.');
  }

  @override
  Widget build(BuildContext c) => PageFrame(
    title: 'Lingoy akkaunti',
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            if (mode == 'login' || mode == 'register') ...[
              const MotionIn(child: JourneyWelcome(account: true)),
              const SizedBox(height: 24),
            ],
            AnimatedSwitcher(
              duration: motionDuration(c, 220),
              child: Align(
                key: ValueKey(mode),
                alignment: Alignment.centerLeft,
                child: Text(
                  {
                    'login': 'Kirish',
                    'register': 'Xush kelibsiz',
                    'verify': 'Emailni tasdiqlang',
                    'forgot': 'Parolni tiklash',
                    'reset': 'Yangi parol belgilang',
                    'change': 'Parolni almashtirish',
                  }[mode]!,
                  style: display(27),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'So‘zlaringiz barcha qurilmalarda siz bilan.',
              style: TextStyle(color: muted(c)),
            ),
            const SizedBox(height: 24),
            if (mode == 'register') ...[
              TextField(
                enabled: !busy,
                controller: name,
                decoration: const InputDecoration(labelText: 'Ismingiz'),
              ),
              const SizedBox(height: 12),
            ],
            if (mode != 'change') ...[
              TextField(
                enabled: !busy,
                controller: email,
                readOnly: mode == 'verify' || mode == 'reset',
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
            ],
            if (mode == 'verify' || mode == 'reset') ...[
              TextField(
                enabled: !busy,
                controller: code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: '6 xonali kod'),
              ),
              const SizedBox(height: 12),
            ],
            if (mode == 'change') ...[
              TextField(
                enabled: !busy,
                controller: old,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Joriy parol'),
              ),
              const SizedBox(height: 12),
            ],
            if (!['forgot', 'verify'].contains(mode))
              TextField(
                enabled: !busy,
                controller: password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: ['reset', 'change'].contains(mode)
                      ? 'Yangi parol'
                      : 'Parol',
                  helperText: mode == 'login' ? null : 'Kamida 10 belgi',
                  prefixIcon: null,
                ),
              ),
            if (mode == 'login')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('forgot-password'),
                  style: TextButton.styleFrom(
                    textStyle: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    foregroundColor: muted(c),
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 4,
                    ),
                  ),
                  onPressed: busy
                      ? null
                      : () => setState(() => mode = 'forgot'),
                  child: const Text('Parolni unutdingizmi?'),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : () => run(submit),
              child: Text(
                busy
                    ? 'Kutilmoqda…'
                    : mode == 'forgot' || mode == 'register'
                    ? 'Kod yuborish'
                    : mode == 'verify'
                    ? 'Tasdiqlash'
                    : mode == 'login'
                    ? 'Kirish'
                    : 'Parolni yangilash',
              ),
            ),
            if (mode == 'verify' || mode == 'reset')
              TextButton(
                onPressed: busy || cooldown > 0 ? null : () => run(send),
                child: Text(
                  cooldown > 0
                      ? 'Qayta yuborish · $cooldown s'
                      : 'Kodni qayta yuborish',
                ),
              ),
            if (mode == 'login') ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy ? null : () => run(google),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 52),
                ),
                icon: const GoogleMark(),
                label: const Text('Google bilan kirish'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() => mode = 'register'),
                child: const Text('Yangi akkaunt yaratish'),
              ),
            ] else
              TextButton(
                onPressed: busy ? null : () => setState(() => mode = 'login'),
                child: const Text('Kirishga qaytish'),
              ),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (message != null)
              Text(message!, style: TextStyle(color: muted(c))),
          ],
        ),
      ),
    ),
  );
}

class AccountCard extends StatelessWidget {
  const AccountCard({super.key});
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: accountApi,
    builder: (c, _) {
      final u = accountApi.user;
      if (u == null) {
        return Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Shaxsiy lug‘atingiz doim yoningizda', style: display(18)),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => requireAccount(c),
                child: const Text('Kirish'),
              ),
            ],
          ),
        );
      }
      return Glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  child: u['picture'] == null
                      ? Text(
                          (u['name'] as String).characters.first.toUpperCase(),
                        )
                      : ClipOval(
                          child: Image.network(
                            u['picture'] as String,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            cacheWidth: 104,
                            errorBuilder: (_, error, stack) => Center(
                              child: Text(
                                (u['name'] as String).characters.first
                                    .toUpperCase(),
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u['name'] as String,
                        style: display(18),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        u['email'] as String,
                        style: TextStyle(fontSize: 12, color: muted(c)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _AccountAction(
              icon: AppIcons.iosShare,
              label: 'Qurilmadagi so‘zlarni ko‘chirish',
              onTap: () async {
                try {
                  final n = await store.importGuestWords();
                  if (c.mounted) {
                    toast(c, '$n ta mehmon so‘zi akkauntga ko‘chirildi.');
                  }
                } catch (_) {
                  if (c.mounted) toast(c, 'Qayta urinib ko‘ring.');
                }
              },
            ),
            _AccountAction(
              icon: AppIcons.privacyTipOutlined,
              label: accountApi.user?['hasPassword'] == false
                  ? 'Parol belgilash'
                  : 'Parolni almashtirish',
              onTap: () => Navigator.push(
                c,
                MaterialPageRoute(
                  builder: (_) => const AccountScreen(changePassword: true),
                ),
              ),
            ),
            _AccountAction(
              icon: AppIcons.arrowOutwardRounded,
              label: 'Akkauntdan chiqish',
              onTap: () async {
                try {
                  await accountApi.logout();
                } catch (e) {
                  if (c.mounted) toast(c, e.toString());
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

class _AccountAction extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  const _AccountAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext c) => PressFeedback(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2),
      minLeadingWidth: 20,
      horizontalTitleGap: 12,
      leading: AppIcon(icon, size: 19, color: muted(c)),
      title: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      trailing: AppIcon(AppIcons.chevronRight, size: 16, color: muted(c)),
      onTap: onTap,
    ),
  );
}
