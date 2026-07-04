import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/admin_peer_profile.dart';

class AdminVoiceCallScreen extends StatefulWidget {
  const AdminVoiceCallScreen({
    super.key,
    required this.channelId,
    required this.token,
    required this.appId,
    required this.peer,
  });

  final String channelId;
  final String token;
  final String appId;
  final AdminPeerProfile peer;

  @override
  State<AdminVoiceCallScreen> createState() => _AdminVoiceCallScreenState();
}

class _AdminVoiceCallScreenState extends State<AdminVoiceCallScreen> {
  RtcEngine? _engine;
  bool _joined = false;
  bool _remoteConnected = false;
  bool _micMuted = false;
  bool _speakerOn = false;
  String? _fatalError;
  DateTime? _callStart;
  Timer? _durationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startCall());
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    unawaited(_disposeEngine());
    super.dispose();
  }

  Future<void> _startCall() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (mounted) {
        setState(() => _fatalError = 'ต้องอนุญาตไมโครโฟนก่อนโทร');
      }
      return;
    }

    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(
        RtcEngineContext(
          appId: widget.appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (_, __) {
            if (!mounted) return;
            setState(() => _joined = true);
          },
          onUserJoined: (_, __, ___) {
            if (!mounted) return;
            setState(() {
              _remoteConnected = true;
              _callStart = DateTime.now();
            });
            _startDurationTicker();
          },
          onUserOffline: (_, __, ___) {
            if (!mounted) return;
            unawaited(_hangUp());
          },
          onError: (err, __) {
            if (!mounted) return;
            if (err == ErrorCodeType.errInvalidToken ||
                err == ErrorCodeType.errTokenExpired) {
              setState(() => _fatalError = 'Token โทรหมดอายุ');
            }
          },
        ),
      );
      await engine.enableAudio();
      await engine.joinChannel(
        token: widget.token,
        channelId: widget.channelId,
        uid: 0,
        options: const ChannelMediaOptions(publishMicrophoneTrack: true),
      );
      if (!mounted) {
        await engine.leaveChannel();
        await engine.release();
        return;
      }
      setState(() => _engine = engine);
    } catch (error) {
      if (mounted) {
        setState(() => _fatalError = 'เชื่อมต่อการโทรไม่สำเร็จ: $error');
      }
    }
  }

  Future<void> _disposeEngine() async {
    final engine = _engine;
    _engine = null;
    if (engine == null) {
      return;
    }
    await engine.leaveChannel();
    await engine.release();
  }

  void _startDurationTicker() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _hangUp() async {
    await _disposeEngine();
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _toggleMute() async {
    final engine = _engine;
    if (engine == null) return;
    final next = !_micMuted;
    await engine.muteLocalAudioStream(next);
    if (mounted) setState(() => _micMuted = next);
  }

  Future<void> _toggleSpeaker() async {
    final engine = _engine;
    if (engine == null) return;
    final next = !_speakerOn;
    await engine.setEnableSpeakerphone(next);
    if (mounted) setState(() => _speakerOn = next);
  }

  String get _statusText {
    if (_fatalError != null) return _fatalError!;
    if (!_joined) return 'กำลังเชื่อมต่อ...';
    if (!_remoteConnected) return 'กำลังเรียก ${widget.peer.displayName}...';
    final start = _callStart;
    if (start == null) return 'สนทนาอยู่';
    final duration = DateTime.now().difference(start);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(widget.peer.displayName),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const Spacer(),
            CircleAvatar(
              radius: 56,
              backgroundColor: const Color(0xFFE65100),
              child: Text(
                widget.peer.displayName.isNotEmpty
                    ? widget.peer.displayName.characters.first.toUpperCase()
                    : 'A',
                style: const TextStyle(color: Colors.white, fontSize: 40),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.peer.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (widget.peer.email != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                widget.peer.email!,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              _statusText,
              style: TextStyle(
                color: _fatalError != null ? Colors.redAccent : Colors.white70,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _CallButton(
                  icon: _speakerOn ? Icons.volume_up : Icons.volume_down,
                  label: 'ลำโพง',
                  onTap: _toggleSpeaker,
                ),
                const SizedBox(width: 24),
                _CallButton(
                  icon: Icons.call_end,
                  label: 'วางสาย',
                  color: Colors.redAccent,
                  onTap: _hangUp,
                ),
                const SizedBox(width: 24),
                _CallButton(
                  icon: _micMuted ? Icons.mic_off : Icons.mic,
                  label: _micMuted ? 'เปิดไมค์' : 'ปิดไมค์',
                  onTap: _toggleMute,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white24,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
