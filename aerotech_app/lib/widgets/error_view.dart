import 'package:aerotech_app/pages/login_page.dart';
import 'package:aerotech_app/services/api_service.dart';
import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const ErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (error is SessionExpiredException) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          LoginPage.irAlLogin(context, (error as ApiException).message);
        }
      });
      return const SizedBox.shrink();
    }

    final isServerDown = error is ServerUnavailableException;
    final message = error is ApiException
        ? (error as ApiException).message
        : 'Ocurrió un error inesperado: $error';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isServerDown ? Icons.cloud_off : Icons.error_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isServerDown ? 'Servidor no disponible' : 'Ocurrió un error',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}