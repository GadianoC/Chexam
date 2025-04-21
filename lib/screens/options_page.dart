import 'package:flutter/material.dart';
import '../utils/cache_utils.dart';

class OptionsPage extends StatelessWidget {
  const OptionsPage({Key? key}) : super(key: key);

  Future<void> _showClearCacheDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('Are you sure you want to clear the image cache? This will delete all cached images.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final result = await clearImageCache();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result ? 'Cache cleared!' : 'Failed to clear cache.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Options')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever),
              label: const Text('Clear Cache'),
              onPressed: () => _showClearCacheDialog(context),
            ),
            const SizedBox(height: 30),
            // Add more options here as needed
            const Text('Other options coming soon...'),
          ],
        ),
      ),
    );
  }
}
