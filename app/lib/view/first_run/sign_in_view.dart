import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/auth_repository.dart';
import '../../viewmodel/session_view_model.dart';
import '../../viewmodel/sign_in_view_model.dart';

class SignInView extends StatelessWidget {
  const SignInView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          SignInViewModel(authRepository: context.read<AuthRepository>()),
      child: const _SignInForm(),
    );
  }
}

class _SignInForm extends StatefulWidget {
  const _SignInForm();

  @override
  State<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<_SignInForm> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SignInViewModel>();
    final isDaftar = viewModel.mode == SignInMode.daftar;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Text('MALAS', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 32),
            SegmentedButton<SignInMode>(
              segments: const [
                ButtonSegment(value: SignInMode.masuk, label: Text('Masuk')),
                ButtonSegment(value: SignInMode.daftar, label: Text('Daftar')),
              ],
              selected: {viewModel.mode},
              onSelectionChanged: (modes) => viewModel.selectMode(modes.single),
            ),
            const SizedBox(height: 24),
            if (isDaftar) ...[
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama'),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor HP'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Kata sandi'),
            ),
            if (viewModel.errorMessage case final message?) ...[
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
              onPressed: viewModel.isSubmitting ? null : _submit,
              child: Text(isDaftar ? 'Daftar' : 'Masuk'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final session = context.read<SessionViewModel>();
    final account = await context.read<SignInViewModel>().submit(
      name: _nameController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
    );
    if (account != null) await session.enter(account);
  }
}
