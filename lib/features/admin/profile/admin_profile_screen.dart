import 'package:flutter/material.dart';

import '../../shared/profile/account_profile_screen.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AccountProfileScreen(
      actorLabel: 'Admin',
      showStoreInfo: false,
      useManagerAppBar: false,
    );
  }
}
