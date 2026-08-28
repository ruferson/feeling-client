import 'package:flutter/material.dart';
import '../config/canvas_constants.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'node_canvas_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool isLoading = false;
  bool useGPS = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, completa todos los campos requeridos.'),
        ),
      );
      return;
    }

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contraseña debe tener al menos 8 caracteres.'),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    Map<String, double>? initialLocation;
    if (!isLogin) {
      if (useGPS) {
        initialLocation = await LocationService.getCurrentGPSLocation();
      } else {
        initialLocation = LocationService.getRandomCoordinates();
      }
    }

    final result = isLogin
        ? await ApiService.login(email, password)
        : await ApiService.register(
            email,
            password,
            longitude: initialLocation?['longitude'],
            latitude: initialLocation?['latitude'],
          );

    setState(() => isLoading = false);

    if (result != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const NodeCanvasScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isLogin
                ? 'Error al iniciar sesión. Revisa tus credenciales.'
                : 'Error al registrar usuario. Comprueba si el email ya existe.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CanvasConstants.backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: CanvasConstants.appBarColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: CanvasConstants.remoteNodeColor.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isLogin ? 'Feeling Canvas - Iniciar Sesión' : 'Crear Cuenta',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Contraseña (mín. 8 caracteres)',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (!isLogin) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => setState(() => useGPS = !useGPS),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Checkbox(
                            value: useGPS,
                            activeColor: CanvasConstants.localNodeColor,
                            onChanged: (val) {
                              setState(() => useGPS = val ?? true);
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'Usar mi posición GPS real al registrarme',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CanvasConstants.localNodeColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isLogin ? 'Entrar' : 'Registrarse',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => isLogin = !isLogin),
                  child: Text(
                    isLogin
                        ? '¿No tienes cuenta? Regístrate'
                        : '¿Ya tienes cuenta? Inicia sesión',
                    style: const TextStyle(
                      color: CanvasConstants.remoteNodeColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
