import 'package:tecstock/pages/home_page.dart';
import 'package:tecstock/pages/login_page.dart';
import 'package:tecstock/pages/gerenciar_empresas_page.dart';
import 'package:tecstock/services/auth_service.dart';
import 'package:tecstock/utils/http_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: HttpHelper.navigatorKey,
      title: 'TecStock',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      locale: const Locale('pt', 'BR'),
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        primaryColor: Colors.deepOrange,
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          focusedBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: Colors.deepOrange, width: 2.0)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthChecker(),
        '/empresas': (context) => const EmpresasAuthChecker(),
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _checkAuthAndLevel(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data!['isLoggedIn'] == true) {
          final nivelAcesso = snapshot.data!['nivelAcesso'] as int?;
          if (nivelAcesso == 0) {
            return const GerenciarEmpresasPage();
          }
          return const HomePage();
        }

        return const LoginPage();
      },
    );
  }

  Future<Map<String, dynamic>> _checkAuthAndLevel() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    int? nivelAcesso;
    if (isLoggedIn) {
      nivelAcesso = await AuthService.getNivelAcesso();
    }

    if (kDebugMode) {
      print('AuthChecker - isLoggedIn: $isLoggedIn, nivelAcesso: $nivelAcesso');
    }

    return {
      'isLoggedIn': isLoggedIn,
      'nivelAcesso': nivelAcesso,
    };
  }
}

class EmpresasAuthChecker extends StatelessWidget {
  const EmpresasAuthChecker({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _checkAuth(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data!['isLoggedIn'] == true) {
          final nivelAcesso = snapshot.data!['nivelAcesso'] as int?;
          if (nivelAcesso == 0) {
            return const GerenciarEmpresasPage();
          } else {
            Future.microtask(() {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Acesso negado. Apenas super administradores podem acessar esta área.'),
                  backgroundColor: Colors.red,
                ),
              );
              Navigator.of(context).pushReplacementNamed('/login');
            });
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
        }

        Future.microtask(() {
          if (!context.mounted) return;
          Navigator.of(context).pushReplacementNamed('/login');
        });
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _checkAuth() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    int? nivelAcesso;
    if (isLoggedIn) {
      nivelAcesso = await AuthService.getNivelAcesso();
    }
    return {
      'isLoggedIn': isLoggedIn,
      'nivelAcesso': nivelAcesso,
    };
  }
}
