import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class StorageSettingsScreen extends ConsumerStatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  ConsumerState<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends ConsumerState<StorageSettingsScreen> {
  String _cacheSize = "Wird berechnet...";
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int size = 0;
      
      if (tempDir.existsSync()) {
        final List<FileSystemEntity> entities = tempDir.listSync(recursive: true, followLinks: false);
        for (var entity in entities) {
          if (entity is File) {
            size += entity.lengthSync();
          }
        }
      }
      
      final double mb = size / (1024 * 1024);
      if (mounted) {
        setState(() {
          _cacheSize = '${mb.toStringAsFixed(2)} MB';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cacheSize = 'Unbekannt';
        });
      }
    }
  }

  Future<void> _clearCache() async {
    if (_isClearing) return;
    
    setState(() {
      _isClearing = true;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final List<FileSystemEntity> entities = tempDir.listSync(recursive: false, followLinks: false);
        for (var entity in entities) {
          try {
            entity.deleteSync(recursive: true);
          } catch (e) {
            // Ignore files that can't be deleted (in use)
          }
        }
      }
      
      await _calculateCacheSize();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache wurde erfolgreich geleert!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fehler beim Leeren des Caches')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daten und Speicher'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Speichernutzung',
              style: TextStyle(
                color: Colors.deepPurple,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.storage, size: 32),
            title: const Text('Zwischenspeicher (Cache)'),
            subtitle: Text('Bilder, Storys und andere temporäre Dateien. Aktuelle Größe: $_cacheSize'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ElevatedButton.icon(
              icon: _isClearing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.delete_outline),
              label: Text(_isClearing ? 'Wird geleert...' : 'Cache jetzt leeren'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade900,
              ),
              onPressed: _isClearing ? null : _clearCache,
            ),
          ),
          
          const Divider(height: 32),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Automatischer Download',
              style: TextStyle(
                color: Colors.deepPurple,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          ListTile(
            title: const Text('Bei mobiler Datenverbindung'),
            subtitle: const Text('Fotos, Audio'),
            onTap: () {
              // Placeholder for future logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download-Einstellungen sind serverseitig immer optimiert.')),
              );
            },
          ),
          ListTile(
            title: const Text('Bei WLAN-Verbindung'),
            subtitle: const Text('Alle Medien'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download-Einstellungen sind serverseitig immer optimiert.')),
              );
            },
          ),
        ],
      ),
    );
  }
}
