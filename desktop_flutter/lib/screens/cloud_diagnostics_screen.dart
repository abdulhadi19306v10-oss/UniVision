import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/bridge_client.dart';

// ponytail: production cloud synchronization diagnostics and real-time activity terminal
class CloudDiagnosticsScreen extends StatefulWidget {
  final BridgeClient client;

  const CloudDiagnosticsScreen({super.key, required this.client});

  @override
  State<CloudDiagnosticsScreen> createState() => _CloudDiagnosticsScreenState();
}

class _CloudDiagnosticsScreenState extends State<CloudDiagnosticsScreen> {
  final TextEditingController _urlCtrl = TextEditingController(text: 'http://127.0.0.1:8000');
  final TextEditingController _emailCtrl = TextEditingController(text: 'teacher@univision.edu');
  final TextEditingController _pwdCtrl = TextEditingController(text: 'teacher123');

  bool _isSyncing = false;
  bool _isTestingConn = false;
  String? _connStatus;
  Map<String, dynamic>? _lastStats;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    final stats = await widget.client.syncToCloud(
      url: _urlCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      password: _pwdCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _lastStats = stats;
      _isSyncing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sync completed: ${stats['synced']} uploaded, ${stats['failed']} failed.'),
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConn = true;
      _connStatus = null;
    });
    final bool ok = await widget.client.testCloudConnection(_urlCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _isTestingConn = false;
      _connStatus = ok ? 'ONLINE: Backend reached successfully' : 'OFFLINE: Unable to connect to backend';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // LEFT: Cloud Sync Configuration Card
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cloud_upload_rounded, color: AppTheme.primary, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cloud Database Synchronization',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Relays verified attendance records to FastAPI Cloud backend.\nRaw face biometrics remain completely offline on this workstation.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  const Text('FastAPI Cloud Endpoint:',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(controller: _urlCtrl),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isTestingConn ? null : _testConnection,
                        icon: Icon(_isTestingConn ? Icons.hourglass_top : Icons.wifi_find_rounded, size: 14),
                        label: Text(_isTestingConn ? 'Testing...' : 'Test Connection', style: const TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      if (_connStatus != null)
                        Expanded(
                          child: Text(
                            _connStatus!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _connStatus!.startsWith('ONLINE') ? AppTheme.success : AppTheme.error,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  const Text('Faculty Account Email:',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(controller: _emailCtrl),
                  const SizedBox(height: 14),

                  const Text('Account Password:',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(controller: _pwdCtrl, obscureText: true),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSyncing ? null : _handleSync,
                      icon: Icon(_isSyncing ? Icons.hourglass_top_rounded : Icons.cloud_sync_rounded, size: 16),
                      label: Text(_isSyncing ? 'Synchronizing with Cloud...' : 'Push Queued Attendance to Cloud'),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_lastStats != null) ...[
                    Row(
                      children: [
                        _buildMetricBox('Uploaded', '${_lastStats!['synced']}', AppTheme.success),
                        const SizedBox(width: 10),
                        _buildMetricBox('Failed', '${_lastStats!['failed']}', AppTheme.error),
                        const SizedBox(width: 10),
                        _buildMetricBox('Pending', '${_lastStats!['pending']}', AppTheme.warning),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // RIGHT: Real-time Activity & Telemetry Terminal
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.terminal_rounded, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Live Telemetry & Diagnostics Log',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        setState(() => widget.client.logMessages.clear());
                      },
                      child: const Text('Clear Log', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSunken,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: widget.client.logMessages.isEmpty
                        ? const Center(
                            child: Text('No telemetry events recorded.', style: TextStyle(color: AppTheme.textMuted)),
                          )
                        : ListView.builder(
                            itemCount: widget.client.logMessages.length,
                            itemBuilder: (context, i) {
                              final msg = widget.client.logMessages[i];
                              Color textColor = AppTheme.textSecondary;
                              if (msg.contains('Error') || msg.contains('Failed') || msg.contains('OFFLINE')) {
                                textColor = AppTheme.error;
                              } else if (msg.contains('Verified') || msg.contains('Confirmed') || msg.contains('Success') || msg.contains('ONLINE')) {
                                textColor = AppTheme.success;
                              } else if (msg.contains('Active') || msg.contains('Started') || msg.contains('Capturing')) {
                                textColor = AppTheme.primary;
                              }
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.5),
                                child: Text(
                                  msg,
                                  style: TextStyle(
                                    fontFamily: 'Consolas',
                                    fontSize: 12,
                                    color: textColor,
                                    height: 1.3,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceSunken,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
