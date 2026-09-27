import 'dart:convert';

import 'dart:typed_data';

import 'package:dcomic/database/sync/database_backup.dart';
import 'package:dcomic/database/sync/sync_models.dart';
import 'package:dcomic/providers/database_sync_service.dart';
import 'package:dcomic/utils/layout_utils.dart';
import 'package:dcomic/view/components/settings_widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DatabaseSyncPage extends StatefulWidget {
  const DatabaseSyncPage({super.key});

  @override
  State<DatabaseSyncPage> createState() => _DatabaseSyncPageState();
}

class _DatabaseSyncPageState extends State<DatabaseSyncPage> {
  bool _backupBusy = false;

  String _text(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DatabaseSyncService>();
    return SettingsPage(
      title: Text(_text('数据库同步与备份', 'Database Sync & Backup')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
          child: Column(
            children: [
              if (service.busy || _backupBusy)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    _buildStatus(service),
                    SettingsSection(title: _text('同步账户', 'Sync account')),
                    _buildAccount(service),
                    SettingsSection(title: _text('自动同步', 'Automatic sync')),
                    _buildSyncControls(service),
                    SettingsSection(title: _text('同步内容', 'Sync categories')),
                    _buildCategories(service),
                    if (service.conflicts.isNotEmpty) ...[
                      SettingsSection(
                        title: _text(
                          '需要处理的冲突',
                          'Conflicts requiring attention',
                        ),
                      ),
                      for (final conflict in service.conflicts)
                        _buildConflict(service, conflict),
                    ],
                    SettingsSection(title: _text('文件备份', 'File backup')),
                    _buildBackup(service),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatus(DatabaseSyncService service) {
    final colors = Theme.of(context).colorScheme;
    final signedIn = service.username != null;
    final status = !signedIn
        ? _text('尚未连接同步服务器', 'Not connected to a sync server')
        : !service.enabled
        ? _text('已登录，自动同步已关闭', 'Signed in; automatic sync is off')
        : service.connected
        ? _text('已连接', 'Connected')
        : _text('等待连接', 'Waiting for connection');
    final icon = !signedIn
        ? Icons.cloud_off_outlined
        : service.connected
        ? Icons.cloud_done_outlined
        : Icons.cloud_sync_outlined;
    final color = service.connected ? colors.primary : colors.onSurfaceVariant;
    return SettingsCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (signedIn)
                      Text(
                        '${service.username} · ${service.serverUrl}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(
                Icons.pending_actions_outlined,
                _text(
                  '待上传 ${service.pendingCount} 项',
                  '${service.pendingCount} pending',
                ),
              ),
              if (service.lastSuccess != null)
                _statusChip(
                  Icons.schedule_outlined,
                  _text(
                    '上次成功 ${_formatTime(service.lastSuccess!)}',
                    'Last success ${_formatTime(service.lastSuccess!)}',
                  ),
                ),
              if (service.conflicts.isNotEmpty)
                _statusChip(
                  Icons.call_split_outlined,
                  _text(
                    '${service.conflicts.length} 个冲突',
                    '${service.conflicts.length} conflicts',
                  ),
                  color: colors.tertiary,
                ),
            ],
          ),
          if (service.error != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: colors.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      service.error!,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(IconData icon, String label, {Color? color}) {
    final colors = Theme.of(context).colorScheme;
    final accent = color ?? colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }

  Widget _buildAccount(DatabaseSyncService service) => SettingsGroup(
    children: [
      SettingsTile(
        leading: Icon(
          service.username == null ? Icons.login : Icons.manage_accounts_outlined,
        ),
        title: Text(
          service.username == null
              ? _text('连接同步账户', 'Connect sync account')
              : _text('更换或重新登录', 'Switch or sign in again'),
        ),
        subtitle: Text(
          _text(
            '这是独立的自托管同步账户，不是漫画源登录。切换账户时必须选择是否迁移本机数据。',
            'This is a separate self-hosted sync account, not a source login. Switching always asks whether to migrate local data.',
          ),
        ),
        enabled: !service.busy,
        onTap: service.busy ? null : () => _showLogin(service),
      ),
      if (service.username != null) ...[
        SettingsTile(
          leading: const Icon(Icons.password_outlined),
          title: Text(_text('修改同步密码', 'Change sync password')),
          subtitle: Text(
            _text(
              '修改后所有设备都会退出，需要使用新密码重新登录。',
              'All devices are signed out after the change and must use the new password.',
            ),
          ),
          enabled: !service.busy,
          onTap: service.busy ? null : () => _showPasswordChange(service),
        ),
        SettingsTile(
          leading: const Icon(Icons.logout),
          title: Text(_text('退出同步账户', 'Sign out of sync account')),
          subtitle: Text(
            _text(
              '撤销此设备会话；本机数据不会删除。',
              'Revokes this device session without deleting local data.',
            ),
          ),
          enabled: !service.busy,
          onTap: service.busy ? null : () => _confirmLogout(service),
        ),
      ],
    ],
  );

  Widget _buildSyncControls(DatabaseSyncService service) => SettingsGroup(
    children: [
      SwitchListTile(
        secondary: const SettingsIcon(child: Icon(Icons.sync_outlined)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        title: Text(_text('在设备间自动同步', 'Sync automatically across devices')),
        subtitle: Text(
          service.username == null
              ? _text('先连接同步账户。', 'Connect a sync account first.')
              : _text(
                  '前台实时接收变更，并定时补拉；后台暂停网络连接。',
                  'Receives changes while foregrounded and polls for safety; networking pauses in background.',
                ),
        ),
        value: service.enabled,
        onChanged: service.username == null || service.busy
            ? null
            : service.setEnabled,
      ),
      SettingsTile(
        leading: const Icon(Icons.sync),
        title: Text(_text('立即同步', 'Sync now')),
        subtitle: Text(
          _text(
            '上传当前待处理变更并拉取服务器更新。',
            'Upload pending changes and pull server updates now.',
          ),
        ),
        enabled: service.enabled && !service.busy,
        onTap: service.enabled && !service.busy ? service.syncNow : null,
      ),
    ],
  );

  Widget _buildCategories(DatabaseSyncService service) => SettingsGroup(
    children: [
      for (final category in SyncCategory.values)
        SwitchListTile(
          secondary: SettingsIcon(child: Icon(_categoryIcon(category))),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          title: Text(_categoryName(category)),
          subtitle: Text(_categoryDescription(category)),
          value: service.categories.contains(category),
          onChanged: service.busy && !service.syncing
              ? null
              : (selected) => _setCategory(service, category, selected),
        ),
    ],
  );

  Widget _buildConflict(
    DatabaseSyncService service,
    SyncConflict conflict,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SettingsCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.call_split_outlined, color: colors.tertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _categoryName(conflict.local.category),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _text(
                '记录：${conflict.local.key}\n“冲突候选”可能来自其他设备，并不一定是当前设备。请根据来源、版本和内容选择最终保留项。',
                'Record: ${conflict.local.key}\nThe conflict candidate may come from another device, not necessarily this one. Compare the source, version, and content before choosing.',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            _buildConflictChoice(
              service,
              conflict,
              record: conflict.local,
              candidate: true,
            ),
            const SizedBox(height: 10),
            _buildConflictChoice(
              service,
              conflict,
              record: conflict.remote,
              candidate: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictChoice(
    DatabaseSyncService service,
    SyncConflict conflict, {
    required SyncRecord record,
    required bool candidate,
  }) {
    final colors = Theme.of(context).colorScheme;
    final device = _shortDevice(record.version.device);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: candidate
            ? colors.tertiaryContainer.withValues(alpha: 0.32)
            : colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            candidate
                ? _text('冲突候选 · 来源设备 $device', 'Candidate · source $device')
                : _text('服务器当前版本 · 来源设备 $device',
                    'Server canonical · source $device'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _versionDescription(record.version),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            _recordPreview(record),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          candidate
              ? FilledButton.tonal(
                  onPressed: service.busy
                      ? null
                      : () => service.resolveConflict(
                          conflict,
                          useLocal: true,
                        ),
                  child: Text(_text('保留此候选版本', 'Keep this candidate')),
                )
              : OutlinedButton(
                  onPressed: service.busy
                      ? null
                      : () => service.resolveConflict(
                          conflict,
                          useLocal: false,
                        ),
                  child: Text(
                    _text('保留服务器当前版本', 'Keep server canonical'),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildBackup(DatabaseSyncService service) => Column(
    children: [
      SettingsNotice(
        icon: Icons.security_outlined,
        child: Text(
          _text(
            '备份是逻辑数据文件，不包含同步令牌和设备游标。包含登录凭据时必须加密，并应只保存到可信位置。',
            'Backups contain logical data, never sync tokens or device cursors. Backups containing source credentials must be encrypted and kept in a trusted location.',
          ),
        ),
      ),
      const SizedBox(height: 10),
      SettingsGroup(
        children: [
          SettingsTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: Text(_text('导出备份文件', 'Export backup file')),
            subtitle: Text(
              _text(
                '选择类别，可使用密码加密后保存。',
                'Choose categories and optionally encrypt with a password.',
              ),
            ),
            enabled: !_backupBusy && service.store != null,
            onTap: _backupBusy || service.store == null
                ? null
                : () => _exportBackup(service),
          ),
          SettingsTile(
            leading: const Icon(Icons.file_download_outlined),
            title: Text(_text('导入备份文件', 'Import backup file')),
            subtitle: Text(
              _text(
                '导入前检查文件并选择合并或替换。',
                'Inspect the file, then choose merge or replace.',
              ),
            ),
            enabled: !_backupBusy && service.store != null,
            onTap: _backupBusy || service.store == null
                ? null
                : () => _importBackup(service),
          ),
        ],
      ),
    ],
  );

  Future<void> _showLogin(DatabaseSyncService service) async {
    final choice = await showDialog<_LoginChoice>(
      context: context,
      builder: (_) => _DatabaseSyncLoginDialog(
        initialUrl: service.serverUrl ?? '',
        initialUsername: service.username ?? '',
      ),
    );
    if (choice == null || !mounted) return;
    await service.login(
      serverUrl: choice.serverUrl,
      username: choice.username,
      password: choice.password,
      migrateLocal: choice.migrate,
    );
  }

  Future<void> _showPasswordChange(DatabaseSyncService service) async {
    final choice = await showDialog<_PasswordChangeChoice>(
      context: context,
      builder: (_) => const _PasswordChangeDialog(),
    );
    if (choice == null) return;
    await service.changePassword(choice.current, choice.next);
  }

  Future<void> _confirmLogout(DatabaseSyncService service) async {
    final confirmed = await _confirm(
      _text('退出同步账户？', 'Sign out of sync account?'),
      _text(
        '服务器将撤销此设备的当前会话。本机漫画数据和备份不会被删除。',
        'The server will revoke this device session. Local comic data and backups are not deleted.',
      ),
    );
    if (confirmed) await service.logout();
  }

  Future<void> _setCategory(
    DatabaseSyncService service,
    SyncCategory category,
    bool selected,
  ) async {
    if (selected && category == SyncCategory.credentials) {
      final confirmed = await _confirm(
        _text('同步登录凭据？', 'Sync source credentials?'),
        _text(
          '这会把漫画源 Cookie、令牌及相关登录配置发送到你的同步服务器，并分发到其他设备。只有在完全信任服务器及其管理员时才启用。',
          'This sends source cookies, tokens, and related login settings to your sync server and other devices. Enable only if you fully trust the server and its administrator.',
        ),
        destructive: true,
      );
      if (!confirmed) return;
    }
    await service.setCategory(category, selected);
  }

  Future<void> _exportBackup(DatabaseSyncService service) async {
    final selected = await _chooseCategories(
      title: _text('选择导出内容', 'Choose export categories'),
      available: SyncCategory.values.toSet(),
      initial: service.categories,
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    final password = await _askBackupPassword(
      credentialsRequired: selected.contains(SyncCategory.credentials),
      importing: false,
    );
    if (password == null || !mounted) return;
    await _runBackup(() async {
      final bytes = await DatabaseBackup(service.store!).export(
        selected,
        password: password.value.isEmpty ? null : password.value,
      );
      final now = DateTime.now();
      final stamp = '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}-'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}';
      final saved = await FilePicker.saveFile(
        fileName: 'dcomic-backup-$stamp.dcomicbackup',
        bytes: bytes,
        mimeType: 'application/octet-stream',
        dialogTitle: _text('保存 DComic 备份', 'Save DComic backup'),
      );
      if (saved != null && mounted) {
        _snack(_text('备份已保存。', 'Backup saved.'));
      }
    });
  }

  Future<void> _importBackup(DatabaseSyncService service) async {
    final file = await FilePicker.pickFile(
      dialogTitle: _text('选择 DComic 备份', 'Choose DComic backup'),
      type: FileType.custom,
      allowedExtensions: const ['dcomicbackup'],
    );
    if (file == null || !mounted) return;
    final password = await _askBackupPassword(
      credentialsRequired: false,
      importing: true,
    );
    if (password == null || !mounted) return;
    await _runBackup(() async {
      final Uint8List bytes = await file.readAsBytes();
      final backup = DatabaseBackup(service.store!);
      final available = await backup.inspect(
        bytes,
        password: password.value.isEmpty ? null : password.value,
      );
      if (!mounted) return;
      final selected = await _chooseCategories(
        title: _text('选择导入内容', 'Choose import categories'),
        available: available,
        initial: available,
      );
      if (selected == null || selected.isEmpty || !mounted) return;
      final replace = await _chooseImportMode();
      if (replace == null || !mounted) return;
      if (replace) {
        final confirmed = await _confirm(
          _text('替换所选类别？', 'Replace selected categories?'),
          _text(
            '替换会删除本机所选类别中备份未包含的记录，并把这些删除作为新变更同步到其他设备。此操作无法自动撤销。',
            'Replace deletes local records in the selected categories when they are absent from the backup, and those deletions can sync to other devices. This cannot be undone automatically.',
          ),
          destructive: true,
        );
        if (!confirmed) return;
      }
      await backup.importData(
        bytes,
        selected,
        password: password.value.isEmpty ? null : password.value,
        replace: replace,
      );
      if (mounted) {
        _snack(
          replace
              ? _text('备份已替换导入。', 'Backup imported with replacement.')
              : _text('备份已合并。', 'Backup merged.'),
        );
      }
      if (service.enabled) await service.syncNow();
    });
  }

  Future<void> _runBackup(Future<void> Function() action) async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      await action();
    } catch (failure) {
      if (mounted) _snack(_backupError(failure));
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<Set<SyncCategory>?> _chooseCategories({
    required String title,
    required Set<SyncCategory> available,
    required Set<SyncCategory> initial,
  }) {
    final selected = initial.intersection(available);
    return showDialog<Set<SyncCategory>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final category in SyncCategory.values)
                if (available.contains(category))
                  CheckboxListTile(
                    value: selected.contains(category),
                    contentPadding: EdgeInsets.zero,
                    title: Text(_categoryName(category)),
                    subtitle: category == SyncCategory.credentials
                        ? Text(
                            _text(
                              '敏感内容；导出时强制使用密码加密。',
                              'Sensitive; export requires password encryption.',
                            ),
                          )
                        : null,
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          selected.add(category);
                        } else {
                          selected.remove(category);
                        }
                      });
                    },
                  ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(
                      dialogContext,
                      Set<SyncCategory>.of(selected),
                    ),
              child: Text(_text('继续', 'Continue')),
            ),
          ],
        ),
      ),
    );
  }

  Future<_PasswordChoice?> _askBackupPassword({
    required bool credentialsRequired,
    required bool importing,
  }) => showDialog<_PasswordChoice>(
    context: context,
    builder: (_) => _BackupPasswordDialog(
      credentialsRequired: credentialsRequired,
      importing: importing,
    ),
  );

  Future<bool?> _chooseImportMode() => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(_text('导入方式', 'Import mode')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.merge_outlined),
            title: Text(_text('合并', 'Merge')),
            subtitle: Text(
              _text(
                '按版本合并备份与本机数据，不主动删除备份中缺少的记录。',
                'Merge by version without deleting records absent from the backup.',
              ),
            ),
            onTap: () => Navigator.pop(dialogContext, false),
          ),
          ListTile(
            leading: Icon(
              Icons.find_replace_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(_text('替换所选类别', 'Replace selected categories')),
            subtitle: Text(
              _text(
                '使所选类别与备份一致；删除会同步到其他设备。',
                'Make selected categories match the backup; deletions can sync to other devices.',
              ),
            ),
            onTap: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    ),
  );

  Future<bool> _confirm(
    String title,
    String message, {
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_text('确认', 'Confirm')),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String _recordPreview(SyncRecord record) {
    if (record.category == SyncCategory.credentials) {
      return _text(
        '内容：[敏感凭据已隐藏]',
        'Content: [sensitive credentials hidden]',
      );
    }
    if (record.deleted) {
      return _text('内容：[已删除记录]', 'Content: [deleted record]');
    }
    final encoded = jsonEncode(record.value);
    final preview = encoded.length <= 320
        ? encoded
        : '${encoded.substring(0, 320)}…';
    return _text('内容：$preview', 'Content: $preview');
  }

  String _versionDescription(SyncVersion version) {
    final time = version.wall > 0
        ? _formatTime(DateTime.fromMillisecondsSinceEpoch(version.wall))
        : _text('未知', 'Unknown');
    return _text(
      '设备：${version.device}\n版本时间：$time · 逻辑序号：${version.logical}',
      'Device: ${version.device}\nVersion time: $time · logical: ${version.logical}',
    );
  }

  String _shortDevice(String device) =>
      device.length <= 24 ? device : '${device.substring(0, 24)}…';

  String _backupError(Object failure) {
    final lower = failure.toString().toLowerCase();
    if (lower.contains('password') ||
        lower.contains('decrypt') ||
        lower.contains('密码') ||
        lower.contains('解密')) {
      return _text(
        '无法解密备份，请检查密码和文件是否完整。',
        'Could not decrypt the backup. Check the password and file integrity.',
      );
    }
    if (lower.contains('size') || lower.contains('large')) {
      return _text('备份文件过大。', 'The backup file is too large.');
    }
    if (lower.contains('format') ||
        lower.contains('version') ||
        lower.contains('invalid') ||
        lower.contains('corrupt')) {
      return _text(
        '备份格式无效、已损坏或版本不受支持。',
        'The backup is invalid, damaged, or uses an unsupported version.',
      );
    }
    return _text('备份操作失败，请重试。', 'The backup operation failed. Try again.');
  }

  String _categoryName(SyncCategory category) {
    if (Localizations.localeOf(context).languageCode == 'zh') {
      return category.label;
    }
    return switch (category) {
      SyncCategory.history => 'Reading history & subscriptions',
      SyncCategory.bindings => 'Comic source bindings',
      SyncCategory.chapterRules => 'Chapter matching rules',
      SyncCategory.settings => 'App settings',
      SyncCategory.sourceSettings => 'Source settings',
      SyncCategory.credentials => 'Source credentials',
    };
  }

  String _categoryDescription(SyncCategory category) => switch (category) {
    SyncCategory.history => _text(
      '阅读进度、历史记录和收藏订阅',
      'Progress, history, and subscriptions',
    ),
    SyncCategory.bindings => _text(
      '跨漫画源的作品对应关系',
      'Cross-source comic relationships',
    ),
    SyncCategory.chapterRules => _text(
      '章节标题等价匹配分组与规则',
      'Chapter-title equivalence groups and rules',
    ),
    SyncCategory.settings => _text(
      '主题、阅读器及应用行为设置',
      'Theme, reader, and app behavior settings',
    ),
    SyncCategory.sourceSettings => _text(
      '不含登录密钥的漫画源设置',
      'Comic-source settings without login secrets',
    ),
    SyncCategory.credentials => _text(
      'Cookie、令牌和登录配置（敏感，默认关闭）',
      'Cookies, tokens, and login configuration (sensitive; off by default)',
    ),
  };

  IconData _categoryIcon(SyncCategory category) => switch (category) {
    SyncCategory.history => Icons.history,
    SyncCategory.bindings => Icons.hub_outlined,
    SyncCategory.chapterRules => Icons.rule_outlined,
    SyncCategory.settings => Icons.tune,
    SyncCategory.sourceSettings => Icons.extension_outlined,
    SyncCategory.credentials => Icons.key_outlined,
  };

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final date = '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    final time = '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PasswordChoice {
  final String value;

  const _PasswordChoice(this.value);
}

class _LoginChoice {
  final String serverUrl;
  final String username;
  final String password;
  final bool migrate;

  const _LoginChoice({
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.migrate,
  });
}

class _PasswordChangeChoice {
  final String current;
  final String next;

  const _PasswordChangeChoice(this.current, this.next);
}

class _DatabaseSyncLoginDialog extends StatefulWidget {
  final String initialUrl;
  final String initialUsername;

  const _DatabaseSyncLoginDialog({
    required this.initialUrl,
    required this.initialUsername,
  });

  @override
  State<_DatabaseSyncLoginDialog> createState() =>
      _DatabaseSyncLoginDialogState();
}

class _DatabaseSyncLoginDialogState extends State<_DatabaseSyncLoginDialog> {
  late final TextEditingController _url;
  late final TextEditingController _username;
  final TextEditingController _password = TextEditingController();
  bool _migrate = false;

  String _text(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.initialUrl);
    _username = TextEditingController(text: widget.initialUsername);
  }

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(_text('连接同步服务器', 'Connect sync server')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: _text('服务器地址', 'Server URL'),
            hintText: 'https://sync.example.com',
            prefixIcon: const Icon(Icons.dns_outlined),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _username,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: _text('同步用户名', 'Sync username'),
            prefixIcon: const Icon(Icons.person_outline),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: _text('同步密码', 'Sync password'),
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            _text('本机现有数据', 'Existing data on this device'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        RadioGroup<bool>(
          groupValue: _migrate,
          onChanged: (value) {
            if (value != null) setState(() => _migrate = value);
          },
          child: Column(
            children: [
              RadioListTile<bool>(
                value: false,
                title: Text(_text('不迁移', 'Do not migrate')),
                subtitle: Text(
                  _text(
                    '现有数据作为仅本机基线；登录后的新修改才会上传。',
                    'Keep existing data as a local baseline; only future edits are uploaded.',
                  ),
                ),
              ),
              RadioListTile<bool>(
                value: true,
                title: Text(_text('迁移到此账户', 'Migrate to this account')),
                subtitle: Text(
                  _text(
                    '把所选类别的现有数据加入上传队列，可能覆盖其他设备上的较旧数据。',
                    'Queue existing selected data for upload; it may replace older data on other devices.',
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_url.text.trim().toLowerCase().startsWith('http://'))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _text(
                '明文 HTTP 不加密密码、令牌和同步数据，仅应在可信网络使用；公网部署建议使用 HTTPS。',
                'Plain HTTP does not encrypt passwords, tokens, or synced data. Use it only on trusted networks; HTTPS is recommended for public servers.',
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _LoginChoice(
            serverUrl: _url.text,
            username: _username.text,
            password: _password.text,
            migrate: _migrate,
          ),
        ),
        child: Text(_text('登录', 'Sign in')),
      ),
    ],
  );
}

class _PasswordChangeDialog extends StatefulWidget {
  const _PasswordChangeDialog();

  @override
  State<_PasswordChangeDialog> createState() => _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends State<_PasswordChangeDialog> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  String? _validation;

  String _text(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(_text('修改同步密码', 'Change sync password')),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final field in [
          (_current, _text('当前密码', 'Current password')),
          (_next, _text('新密码', 'New password')),
          (_confirm, _text('确认新密码', 'Confirm new password')),
        ]) ...[
          TextField(
            controller: field.$1,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: field.$2,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_validation != null)
          Text(
            _validation!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
      FilledButton(
        onPressed: () {
          if (_next.text.isEmpty || _next.text != _confirm.text) {
            setState(() {
              _validation = _text(
                '两次输入的新密码不一致或为空。',
                'The new passwords are empty or do not match.',
              );
            });
            return;
          }
          Navigator.pop(
            context,
            _PasswordChangeChoice(_current.text, _next.text),
          );
        },
        child: Text(_text('修改并退出', 'Change and sign out')),
      ),
    ],
  );
}

class _BackupPasswordDialog extends StatefulWidget {
  final bool credentialsRequired;
  final bool importing;

  const _BackupPasswordDialog({
    required this.credentialsRequired,
    required this.importing,
  });

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  String? _validation;

  String _text(String zh, String en) =>
      Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(
      widget.importing
          ? _text('备份密码', 'Backup password')
          : _text('加密备份', 'Encrypt backup'),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.importing
              ? _text(
                  '如果文件已加密，请输入密码；未加密文件可留空。',
                  'Enter the password if the file is encrypted; leave blank for an unencrypted file.',
                )
              : widget.credentialsRequired
              ? _text(
                  '所选内容包含登录凭据，必须设置备份密码。密码丢失后无法恢复。',
                  'The selection contains credentials, so a backup password is required. A lost password cannot be recovered.',
                )
              : _text(
                  '设置密码可加密整个备份；留空则创建未加密备份。',
                  'Set a password to encrypt the entire backup, or leave blank for an unencrypted backup.',
                ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: _text('密码', 'Password'),
            border: const OutlineInputBorder(),
          ),
        ),
        if (!widget.importing) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: _text('确认密码', 'Confirm password'),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
        if (_validation != null) ...[
          const SizedBox(height: 8),
          Text(
            _validation!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
      FilledButton(
        onPressed: () {
          if (widget.credentialsRequired && _password.text.isEmpty) {
            setState(() {
              _validation = _text(
                '包含凭据的备份必须设置密码。',
                'A password is required when credentials are included.',
              );
            });
            return;
          }
          if (!widget.importing && _password.text != _confirm.text) {
            setState(() {
              _validation = _text(
                '两次输入的密码不一致。',
                'The passwords do not match.',
              );
            });
            return;
          }
          Navigator.pop(context, _PasswordChoice(_password.text));
        },
        child: Text(_text('继续', 'Continue')),
      ),
    ],
  );
}
