import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/auth_repository.dart';
import '../../viewmodel/session_view_model.dart';
import '../../viewmodel/sign_in_view_model.dart';
import '../theme/brand_header.dart';
import '../theme/lip.dart';
import '../theme/tokens.dart';

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
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          BrandHeader(
            title: isDaftar ? 'Daftar' : 'Masuk',
            subtitle: 'MALAS',
            height: _formHeaderHeight,
            // Non-empty actions suppresses coins so this form keeps hills only
            // (DESIGN.md §5.4).
            actions: const [SizedBox.shrink()],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MalasSpace.screen,
              MalasSpace.s16,
              MalasSpace.screen,
              MalasSpace.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isDaftar) ...[
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: MalasText.body,
                    decoration: const InputDecoration(labelText: 'Nama'),
                  ),
                  const SizedBox(height: MalasSpace.s16),
                ],
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: MalasText.body,
                  decoration: const InputDecoration(labelText: 'Nomor HP'),
                ),
                const SizedBox(height: MalasSpace.s16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: MalasText.body,
                  decoration: const InputDecoration(labelText: 'Kata sandi'),
                ),
                if (viewModel.errorMessage case final message?) ...[
                  const SizedBox(height: MalasSpace.s16),
                  Text(
                    message,
                    style: MalasText.bodySecondary.copyWith(
                      color: MalasColors.textError,
                    ),
                  ),
                ],
                const SizedBox(height: MalasSpace.s24),
                LipButton(
                  label: isDaftar ? 'Daftar' : 'Masuk',
                  onPressed: viewModel.isSubmitting ? null : _submit,
                ),
                const SizedBox(height: MalasSpace.s12),
                TextButton(
                  onPressed: () => viewModel.selectMode(
                    isDaftar ? SignInMode.masuk : SignInMode.daftar,
                  ),
                  child: Text(isDaftar ? 'Masuk' : 'Daftar'),
                ),
              ],
            ),
          ),
        ],
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

const _formHeaderHeight = 148.0;
