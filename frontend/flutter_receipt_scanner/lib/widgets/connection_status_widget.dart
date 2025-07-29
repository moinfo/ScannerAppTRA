import 'package:flutter/material.dart';
import '../main.dart';

class ConnectionStatusWidget extends StatefulWidget {
  const ConnectionStatusWidget({Key? key}) : super(key: key);

  @override
  State<ConnectionStatusWidget> createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<ConnectionStatusWidget> {
  Map<String, dynamic>? _connectionStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    setState(() => _isLoading = true);
    try {
      final status = await ApiConfig.getConnectionStatus();
      setState(() {
        _connectionStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _connectionStatus = {
          'error': e.toString(),
          'localIP': 'Unknown',
          'backendReachable': false,
          'scraperReachable': false,
        };
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Connection Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _checkConnection,
                  tooltip: 'Refresh Status',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_connectionStatus != null) ...[
              _buildStatusRow(
                'Local IP',
                _connectionStatus!['localIP'],
                Icons.network_wifi,
                Colors.blue,
              ),
              _buildStatusRow(
                'Backend API',
                _connectionStatus!['backendUrl'],
                Icons.api,
                _connectionStatus!['backendReachable'] ? Colors.green : Colors.red,
                isReachable: _connectionStatus!['backendReachable'],
              ),
              _buildStatusRow(
                'TRA Scraper',
                _connectionStatus!['scraperUrl'],
                Icons.scanner,
                _connectionStatus!['scraperReachable'] ? Colors.green : Colors.red,
                isReachable: _connectionStatus!['scraperReachable'],
              ),
              const SizedBox(height: 8),
              Text(
                'Last checked: ${_formatTime(_connectionStatus!['lastChecked'])}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              if (_connectionStatus!['error'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Error: ${_connectionStatus!['error']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  await ApiConfig.refreshIP();
                  _checkConnection();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh IP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool? isReachable,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (isReachable != null)
            Icon(
              isReachable ? Icons.check_circle : Icons.error,
              color: isReachable ? Colors.green : Colors.red,
              size: 16,
            ),
        ],
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inSeconds < 60) {
        return '${difference.inSeconds}s ago';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else {
        return '${difference.inHours}h ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}