import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/shared/widgets/dot_grid_panel.dart';
import 'package:sentech_connect_app/shared/widgets/sentech_logo.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLoggedIn, required this.onRegister});

  final VoidCallback onLoggedIn;
  final VoidCallback onRegister;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.success) widget.onLoggedIn();
          if (state.status == AuthStatus.failure && state.errorMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        builder: (context, state) {
          final loading = state.status == AuthStatus.loading;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: SentechLogo(height: 44)),
                  const SizedBox(height: 24),
                  const DotGridPanel(height: 130),
                  const SizedBox(height: 24),
                  Text('Welcome back', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Log in to manage your connection',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: loading ? null : () => context.read<AuthCubit>().logInWithBiometrics(),
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Log in with Face ID'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('or', style: theme.textTheme.bodyMedium),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(hintText: 'Mobile number'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: 'Password'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: loading
                        ? null
                        : () => context.read<AuthCubit>().logIn(
                              mobileNumber: _mobileController.text,
                              password: _passwordController.text,
                            ),
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Log in'),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: loading ? null : widget.onRegister,
                    child: const Text('New to Sentech? Create an account'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
