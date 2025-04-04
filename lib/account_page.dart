import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'auth_page.dart';
import 'canteen_page.dart';

class AccountPage extends StatelessWidget {
  final AuthService _authService = AuthService();

  AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = _authService.getCurrentUser();
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (user == null) {
      return const AuthPage();
    }

    _authService.migrateExistingUser(user);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            user.photoURL != null
                ? CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(user.photoURL!),
                  backgroundColor: accentColor,
                  onBackgroundImageError:
                      (_, __) => CircleAvatar(
                        radius: 50,
                        backgroundColor: accentColor,
                        child: Text(
                          (user.displayName?.isNotEmpty == true)
                              ? user.displayName![0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                )
                : CircleAvatar(
                  radius: 50,
                  backgroundColor: accentColor,
                  child: Text(
                    (user.displayName?.isNotEmpty == true)
                        ? user.displayName![0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
            const SizedBox(height: 16),

            FutureBuilder<String>(
              future: _authService.getUserName(user.uid),
              builder: (context, snapshot) {
                final displayName = snapshot.data ?? user.displayName ?? 'User';
                return Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              },
            ),

            Text(
              user.email ?? '',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 32),
            ListTile(
              leading: Icon(
                Icons.edit,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                'Edit Profile',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              onTap: () {},
            ),
            ListTile(
              leading: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                'Sign Out',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              onTap: () async {
                await _authService.signOut();
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: accentColor,
                    child: Icon(Icons.restaurant, color: primaryColor),
                  ),
                  title: const Text('Canteen Availability'),
                  subtitle: const Text('Check and update canteen status'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CanteenPage(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
