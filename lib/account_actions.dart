import 'package:flutter/material.dart';

import 'taskhub_api.dart';

Future<void> accountAction(BuildContext context, String action) async {
  final password = TextEditingController();
  final replacement = TextEditingController();
  final email = TextEditingController();
  final code = TextEditingController();
  final recovery = action == 'recover';
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(switch (action) {
        'delete' => 'Delete account and owned groups?',
        'password' => 'Change password',
        'recover' => 'Recover account',
        _ => 'Create a recovery code',
      }),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (action == 'delete')
              const Text(
                'This permanently deletes your account, personal planner and groups you own.',
              ),
            if (action == 'recovery-code')
              const Text(
                'Keep the code somewhere safe. It replaces any previous code and can reset your password once.',
              ),
            if (recovery) ...[
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Recovery code'),
              ),
            ] else
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
              ),
            if (recovery || action == 'password')
              TextField(
                controller: replacement,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password (12+ characters)',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  try {
    if (accepted != true) return;
    final result = await TaskHubApi.shared.call(
      'POST',
      recovery ? '/api/v1/auth/recover' : '/api/v1/account/$action',
      {
        'password': password.text,
        'newPassword': replacement.text,
        'email': email.text.trim(),
        'recoveryCode': code.text.trim(),
      },
    );
    if (action == 'delete' || action == 'password') {
      await TaskHubApi.shared.clearSession(deleted: action == 'delete');
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Done'),
        content: SelectableText(
          result['recoveryCode'] as String? ??
              (recovery || action == 'password'
                  ? 'Sign in with your new password.'
                  : 'Account deleted.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  } finally {
    // Dialog closing animation may still use its text controllers.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    password.dispose();
    replacement.dispose();
    email.dispose();
    code.dispose();
  }
}
