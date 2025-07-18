import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  final Size preferredSize;

  const MainAppBar({Key? key})
    : preferredSize = const Size.fromHeight(kToolbarHeight),
      super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;

    return AppBar(
      title: Row(
        children: [
          const Text('Nürnberg', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      backgroundColor: const Color.fromARGB(255, 106, 63, 156),
      actions: [
        IconButton(
          icon: const Icon(Icons.account_circle),
          onPressed: () => _handleAuth(context, auth),
        ),
      ],
    );
  }

  void _handleAuth(BuildContext context, GoTrueClient auth) {
    if (auth.currentUser != null) {
      // Zeige Profil-Dialog oder Logout-Option
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Angemeldet als ${auth.currentUser?.email}"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Schließen"),
            ),
            TextButton(
              onPressed: () async {
                await auth.signOut();
                Navigator.pop(context);
              },
              child: Text("Abmelden"),
            ),
          ],
        ),
      );
    } else {
      // Navigiere zur Login-Seite
      Navigator.pushNamed(context, '/login');
    }
  }
}

class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  const BottomNavBar({Key? key, required this.currentIndex}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Karte'),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline),
          label: 'Neue Meldung',
        ),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, '/');
            break;
          case 1:
            Navigator.pushReplacementNamed(context, '/karte');
            break;
          case 2:
            Navigator.pushReplacementNamed(context, '/neuemeldung');
            break;
        }
      },
    );
  }
}
