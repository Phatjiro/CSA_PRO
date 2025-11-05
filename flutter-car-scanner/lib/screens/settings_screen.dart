import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '1.0.0';
  String _appName = 'Car Scanner';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
          _appName = packageInfo.appName;
        });
      }
    } catch (_) {
      // Use defaults if package info fails
    }
  }

  Future<void> _rateApp() async {
    // Try to open app store
    final url = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.kahastudio.obd2scanner',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open app store')),
        );
      }
    }
  }

  Future<void> _contactSupport() async {
    final email = Uri(
      scheme: 'mailto',
      path: 'support@cascanner.com',
      query: 'subject=Car Scanner Support',
    );
    if (await canLaunchUrl(email)) {
      await launchUrl(email);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open email client')),
        );
      }
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_appName, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Version: $_appVersion'),
            const SizedBox(height: 16),
            const Text(
              'Professional OBD-II car scanner application for vehicle diagnostics and monitoring.',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text(
              '© 2024 CSA_PRO Team',
              style: TextStyle(fontSize: 11, color: Colors.white60),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            SizedBox(width: 8),
            Text('Upgrade to Pro'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unlock premium features:'),
            SizedBox(height: 12),
            _FeatureItem('Unlimited vehicles'),
            _FeatureItem('Advanced analytics'),
            _FeatureItem('Cloud sync'),
            _FeatureItem('Export reports'),
            _FeatureItem('Priority support'),
            _FeatureItem('Ad-free experience'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Upgrade feature coming soon')),
              );
            },
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // Account Section
          _SectionHeader(title: 'Account'),
          _SettingsTile(
            icon: Icons.star,
            title: 'Rate App',
            subtitle: 'Help us improve with your feedback',
            trailing: const Icon(Icons.chevron_right),
            onTap: _rateApp,
          ),
          _SettingsTile(
            icon: Icons.workspace_premium,
            title: 'Upgrade to Pro',
            subtitle: 'Unlock premium features',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'PRO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            onTap: _showUpgradeDialog,
          ),
          const Divider(height: 1),

          // Support Section
          _SectionHeader(title: 'Support'),
          _SettingsTile(
            icon: Icons.email,
            title: 'Contact Support',
            subtitle: 'support@cascanner.com',
            trailing: const Icon(Icons.chevron_right),
            onTap: _contactSupport,
          ),
          _SettingsTile(
            icon: Icons.help_outline,
            title: 'Help & FAQ',
            subtitle: 'Get help with common questions',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help & FAQ coming soon')),
              );
            },
          ),
          const Divider(height: 1),

          // About Section
          _SectionHeader(title: 'About'),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App version and information',
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAboutDialog,
          ),
          _SettingsTile(
            icon: Icons.description,
            title: 'Privacy Policy',
            subtitle: 'How we handle your data',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy Policy coming soon')),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.description,
            title: 'Terms of Service',
            subtitle: 'Terms and conditions',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Terms of Service coming soon')),
              );
            },
          ),
          const Divider(height: 1),

          // App Info Footer
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Text(
                    _appName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version $_appVersion',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '© 2024 CSA_PRO Team',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final String text;
  const _FeatureItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

