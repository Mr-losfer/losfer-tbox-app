import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/dl_client.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/theme.dart';
import 'player.dart';
import 'settings.dart';
import 'widgets.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, a, _) => const _DownloadsView(),
        transitionsBuilder: (_, a, _, child) => SlideTransition(
          position: Tween(begin: const Offset(0, .04), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
        ),
      );

  @override
  Widget build(BuildContext context) => const _DownloadsView();
}

class _DownloadsView extends StatefulWidget {
  const _DownloadsView();

  @override
  State<_DownloadsView> createState() => _DownloadsViewState();
}

class _DownloadsViewState extends State<_DownloadsView> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  DlClient? _client;
  List<DlTask> _active = const [];
  List<DlTask> _done = const [];
  bool _loading = true;
  String? _error;
  Timer? _poll;
  final _urlCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _init();
  }

  void _init() {
    final st = context.read<AppState>();
    if (!st.dlEnabled || st.dlBase.isEmpty) {
      setState(() {
        _client = null;
        _loading = false;
      });
      return;
    }
    _client = DlClient(st.dlBase, st.dlKey);
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tab.dispose();
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final c = _client;
    if (c == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final futures = await Future.wait([
        c.tasks(status: 'active', limit: 50),
        c.tasks(status: 'completed', limit: 50),
      ]);
      if (!mounted) return;
      setState(() {
        _active = futures[0];
        _done = futures[1];
        _loading = false;
      });
      _schedulePoll();
    } on DlException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '下载服务连接失败';
        _loading = false;
      });
    }
  }

  void _schedulePoll() {
    _poll?.cancel();
    if (_active.isNotEmpty) {
      _poll = Timer(const Duration(seconds: 2), () async {
        await _pollOnce();
        if (mounted) _schedulePoll();
      });
    }
  }

  Future<void> _pollOnce() async {
    final c = _client;
    if (c == null) return;
    try {
      final a = await c.tasks(status: 'active', limit: 50);
      final d = await c.tasks(status: 'completed', limit: 50);
      if (!mounted) return;
      setState(() {
        _active = a;
        _done = d;
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    final c = _client;
    final url = _urlCtrl.text.trim();
    if (c == null || url.isEmpty) return;
    final s = context.read<AppState>().s;
    try {
      await c.submit(url: url, title: _titleCtrl.text.trim());
      _urlCtrl.clear();
      _titleCtrl.clear();
      if (mounted) {
        Toast.show(context, s.t('dlSubmitted'));
        _tab.animateTo(0);
        await _refresh();
      }
    } on DlException catch (e) {
      if (mounted) Toast.show(context, e.message);
    } catch (_) {
      if (mounted) Toast.show(context, '提交失败');
    }
  }

  Future<void> _cancel(DlTask t) async {
    try {
      await _client?.cancel(t.id);
      await _refresh();
    } on DlException catch (e) {
      if (mounted) Toast.show(context, e.message);
    }
  }

  Future<void> _retry(DlTask t) async {
    try {
      await _client?.retry(t.id);
      await _refresh();
    } on DlException catch (e) {
      if (mounted) Toast.show(context, e.message);
    }
  }

  Future<void> _delete(DlTask t, {bool file = false}) async {
    try {
      await _client?.delete(t.id, file: file);
      await _refresh();
    } on DlException catch (e) {
      if (mounted) Toast.show(context, e.message);
    }
  }

  void _play(DlTask t) {
    final c = _client;
    if (c == null) return;
    Navigator.of(context).push(PlayerPage.route(
      vod: Vod(id: t.id, name: t.title),
      site: '',
      sourceIndex: 0,
      episodeIndex: 0,
      directUrl: c.streamUrl(t.id),
    ));
  }

  Future<void> _openExternal(DlTask t) async {
    final c = _client;
    if (c == null) return;
    final uri = Uri.parse(c.downloadUrl(t.id));
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = st.s;
    if (_client == null) {
      return Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(C.pad, 10, C.pad, 30),
            children: [
              Row(
                children: [
                  IconPill(icon: Icons.arrow_back_rounded, size: 36, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Text(s.t('downloadList'), style: T.h2),
                ],
              ),
              const SizedBox(height: 60),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(color: C.surface, shape: BoxShape.circle, border: Border.all(color: C.line)),
                      child: const Icon(Icons.cloud_download_outlined, size: 28, color: C.sub),
                    ),
                    const SizedBox(height: 18),
                    Text(s.t('dlNotConfig'), style: T.h3.copyWith(fontSize: 15)),
                    const SizedBox(height: 8),
                    Text(s.t('dlEnableSub'), style: T.cap.copyWith(fontSize: 12.5)),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: 200,
                      child: GoldButton(
                        label: s.t('dlConfig'),
                        onTap: () async {
                          await Navigator.of(context).push(SettingsPage.route());
                          _init();
                        },
                        height: 46,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(C.pad, 10, C.pad, 0),
              child: Row(
                children: [
                  IconPill(icon: Icons.arrow_back_rounded, size: 36, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Text(s.t('downloadList'), style: T.h2),
                  const Spacer(),
                  IconPill(icon: Icons.refresh_rounded, size: 36, onTap: _refresh),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SubmitBar(
              urlCtrl: _urlCtrl,
              titleCtrl: _titleCtrl,
              onSubmit: _submit,
              hint: s.t('dlBaseHint'),
            ),
            const SizedBox(height: 6),
            TabBar(
              controller: _tab,
              labelColor: C.accent,
              unselectedLabelColor: C.faint,
              indicatorColor: C.accent,
              labelStyle: T.cap.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700),
              tabs: [
                Tab(text: '${s.t('dlRunning')} (${_active.length})'),
                Tab(text: '${s.t('dlCompleted')} (${_done.length})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _TaskList(
                    tasks: _active,
                    loading: _loading,
                    error: _error,
                    emptyText: s.t('dlEmpty'),
                    onRefresh: _refresh,
                    onCancel: _cancel,
                    onRetry: _retry,
                    onDelete: _delete,
                    onPlay: _play,
                    onOpen: _openExternal,
                  ),
                  _TaskList(
                    tasks: _done,
                    loading: _loading,
                    error: _error,
                    emptyText: s.t('dlEmpty'),
                    onRefresh: _refresh,
                    onCancel: _cancel,
                    onRetry: _retry,
                    onDelete: _delete,
                    onPlay: _play,
                    onOpen: _openExternal,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.urlCtrl, required this.titleCtrl, required this.onSubmit, required this.hint});
  final TextEditingController urlCtrl;
  final TextEditingController titleCtrl;
  final VoidCallback onSubmit;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(C.pad, 4, C.pad, 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
              child: TextField(
                controller: urlCtrl,
                style: T.body.copyWith(fontSize: 12.5),
                decoration: InputDecoration(border: InputBorder.none, hintText: 'https://…  $hint', hintStyle: T.cap.copyWith(fontSize: 11)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 42,
            child: GoldButton(label: '提交', onTap: onSubmit, height: 42, expanded: false),
          ),
        ],
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.tasks,
    required this.loading,
    required this.error,
    required this.emptyText,
    required this.onRefresh,
    required this.onCancel,
    required this.onRetry,
    required this.onDelete,
    required this.onPlay,
    required this.onOpen,
  });
  final List<DlTask> tasks;
  final bool loading;
  final String? error;
  final String emptyText;
  final VoidCallback onRefresh;
  final ValueChanged<DlTask> onCancel;
  final ValueChanged<DlTask> onRetry;
  final Function(DlTask, {bool file}) onDelete;
  final ValueChanged<DlTask> onPlay;
  final ValueChanged<DlTask> onOpen;

  @override
  Widget build(BuildContext context) {
    if (loading && tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 1.6, color: C.faint));
    }
    if (error != null && tasks.isEmpty) {
      return ErrorView(message: error!, onRetry: onRefresh, retryLabel: '重试');
    }
    if (tasks.isEmpty) {
      return Center(child: EmptyView(text: emptyText));
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: C.accent,
      backgroundColor: C.surface,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(C.pad, 10, C.pad, 30),
        itemCount: tasks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _TaskCard(
          task: tasks[i],
          onCancel: onCancel,
          onRetry: onRetry,
          onDelete: onDelete,
          onPlay: onPlay,
          onOpen: onOpen,
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onCancel,
    required this.onRetry,
    required this.onDelete,
    required this.onPlay,
    required this.onOpen,
  });
  final DlTask task;
  final ValueChanged<DlTask> onCancel;
  final ValueChanged<DlTask> onRetry;
  final Function(DlTask, {bool file}) onDelete;
  final ValueChanged<DlTask> onPlay;
  final ValueChanged<DlTask> onOpen;

  Color _statusColor() {
    if (task.completed) return C.accent;
    if (task.failed) return C.vip;
    if (task.canceled) return C.faint;
    return C.accent;
  }

  String _statusText(S s) {
    switch (task.status) {
      case 'queued':
        return s.t('dlQueued');
      case 'running':
        return s.t('dlRunning');
      case 'merging':
        return s.t('dlMerge');
      case 'completed':
        return s.t('dlCompleted');
      case 'failed':
        return s.t('dlFailed');
      case 'canceled':
        return s.t('dlCanceled');
      default:
        return task.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().s;
    final showProgress = task.active;
    return Container(
      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(task.title.isEmpty ? task.url : task.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: T.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor().withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(_statusText(s), style: T.tiny.copyWith(fontSize: 10.5, color: _statusColor(), fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (task.saveDir.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${s.t('dlSaveDir')}: ${task.saveDir}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.tiny.copyWith(fontSize: 10.5, color: C.faint)),
          ],
          const SizedBox(height: 10),
          if (showProgress) ...[
            ClipRoundedrect(
              height: 6,
              value: task.progress / 100,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('${task.progress}%', style: T.cap.copyWith(fontSize: 11, color: C.sub)),
                const SizedBox(width: 8),
                Expanded(child: Text(_fmtSize(task.downloaded, task.size), style: T.tiny.copyWith(fontSize: 10.5, color: C.faint))),
                if (task.speed.isNotEmpty)
                  Text(task.speed, style: T.tiny.copyWith(fontSize: 10.5, color: C.faint)),
              ],
            ),
          ] else if (task.completed) ...[
            Text(_fmtSize(task.size, task.size), style: T.cap.copyWith(fontSize: 11, color: C.sub)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (task.completed) ...[
                Expanded(child: GoldButton(label: s.t('dlPlay'), icon: Icons.play_arrow_rounded, height: 38, onTap: () => onPlay(task))),
                const SizedBox(width: 8),
                Expanded(child: GhostButton(label: s.t('dlOpen'), icon: Icons.open_in_new_rounded, height: 38, onTap: () => onOpen(task))),
              ] else if (task.active) ...[
                Expanded(child: GhostButton(label: s.t('dlCancel'), icon: Icons.stop_circle_outlined, height: 38, onTap: () => onCancel(task))),
              ] else ...[
                Expanded(child: GoldButton(label: s.t('dlRetry'), icon: Icons.refresh_rounded, height: 38, onTap: () => onRetry(task))),
              ],
              const SizedBox(width: 8),
              SizedBox(
                height: 38,
                child: GhostButton(
                  label: s.t('dlDelete'),
                  height: 38,
                  icon: Icons.delete_outline_rounded,
                  onTap: () => onDelete(task, file: task.completed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtSize(int a, int b) {
    String fmt(int v) {
      if (v <= 0) return '—';
      const u = ['B', 'KB', 'MB', 'GB', 'TB'];
      var x = v.toDouble();
      var i = 0;
      while (x >= 1024 && i < u.length - 1) {
        x /= 1024;
        i++;
      }
      return '${x.toStringAsFixed(x < 10 ? 2 : 1)} ${u[i]}';
    }

    if (b > 0 && a > 0) return '${fmt(a)} / ${fmt(b)}';
    return fmt(a);
  }
}

class ClipRoundedrect extends StatelessWidget {
  const ClipRoundedrect({super.key, required this.value, this.height = 6});
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(color: C.surfaceHi, borderRadius: BorderRadius.circular(height)),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(height))),
        ),
      );
}
