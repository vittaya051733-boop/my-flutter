import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import 'models/user_profile.dart';

class CallScreen extends StatefulWidget {
  final String channelName;
  final bool isVideo;
  final UserProfile targetProfile;
  final bool isIncoming;
  final String? tokenOverride;
  final String? channelOverride;
  const CallScreen({
    super.key,
    required this.channelName,
    required this.isVideo,
    required this.targetProfile,
    this.isIncoming = false,
    this.tokenOverride,
    this.channelOverride,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late RtcEngine _engine;
  bool _joined = false;
  int? _remoteUid;
  bool _speakerOn = false;
  bool _micMuted = false;
  late final String _activeToken;
  late final String _activeChannelId;
  bool _incomingAccepted = false;

  // Agora App ID
  static const String appId = '37050f5308fd450ba070b53c01596c06';
  // ตัวอย่าง token/channel (ใช้เฉพาะกรณีไม่มีข้อมูลจริง)
  static const String _sampleToken = '007eJxTYGBs0PGfuPCu6/wSIbNKyctefpeSNX1jdtd9NrllcU9/D68Cg7G5galBmqmxgUVaiompQVKigblBkqlxsoGhqaVZsoHZo48ymQ2BjAwfdbhYGRlYGRgZmBhAfAYGAOqgG1Y=';
  static const String _sampleChannel = 'tam';

  @override
  void initState() {
    super.initState();
    // ใช้ token และ channel จริงจาก backend/FCM ถ้ามี
    _activeToken = (widget.tokenOverride != null && widget.tokenOverride!.trim().isNotEmpty)
        ? widget.tokenOverride!.trim()
        : _sampleToken;
    _activeChannelId = (widget.channelOverride != null && widget.channelOverride!.trim().isNotEmpty)
        ? widget.channelOverride!.trim()
        : (widget.channelName.isNotEmpty ? widget.channelName : _sampleChannel);
    if (!widget.isIncoming) {
      _initAgora();
    }
  }

  Future<void> _initAgora() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(appId: appId));
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          setState(() {
            _joined = true;
          });
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (connection, remoteUid, reason) {
          setState(() {
            _remoteUid = null;
          });
        },
      ),
    );
    if (widget.isVideo) {
      await _engine.enableVideo();
    } else {
      await _engine.enableAudio();
    }
    await _engine.joinChannel(
      token: _activeToken,
      channelId: _activeChannelId,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  void _toggleSpeaker() {
    _engine.setEnableSpeakerphone(!_speakerOn);
    setState(() => _speakerOn = !_speakerOn);
  }

  void _toggleMute() {
    _engine.muteLocalAudioStream(!_micMuted);
    setState(() => _micMuted = !_micMuted);
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isIncoming && !_incomingAccepted) {
      return Scaffold(
        backgroundColor: widget.isVideo ? Colors.black : const Color(0xFFF5F5F7),
        body: _buildIncomingContent(),
      );
    }
    return Scaffold(
      backgroundColor: widget.isVideo ? Colors.black : const Color(0xFFF5F5F7),
      body: widget.isVideo ? _buildVideoContent() : _buildVoiceContent(),
    );
  }

  Widget _buildIncomingContent() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF374049), Color(0xFF1F252B)],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                children: [
                  Text('มีสายเข้า', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 12),
                  Text(
                    widget.targetProfile.displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Container(
              width: 160,
              height: 160,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
              child: ClipOval(
                child: widget.targetProfile.photoUrl != null
                    ? Image.network(widget.targetProfile.photoUrl!, fit: BoxFit.cover)
                    : Center(
                        child: Text(
                          widget.targetProfile.displayName.characters.first.toUpperCase(),
                          style: const TextStyle(fontSize: 64, color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CallActionButton(
                    icon: Icons.call,
                    label: 'รับสาย',
                    color: const Color(0xFF00B900),
                    onTap: () {
                      setState(() {
                        _incomingAccepted = true;
                      });
                      _initAgora();
                    },
                  ),
                  const SizedBox(width: 32),
                  _CallActionButton(
                    icon: Icons.call_end,
                    label: 'ไม่รับ',
                    color: Colors.redAccent,
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    final statusText = !_joined
        ? 'กำลังเชื่อมต่อ...'
        : _remoteUid == null
            ? 'กำลังโทรหา (วิดีโอ)'
            : 'กำลังสนทนากับ';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF23272A), Color(0xFF181A1B)],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                children: [
                  Text(statusText, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 12),
                  Text(
                    widget.targetProfile.displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: _joined
                    ? (_remoteUid != null
                        ? AgoraVideoView(
                            controller: VideoViewController.remote(
                              rtcEngine: _engine,
                              canvas: VideoCanvas(uid: _remoteUid!),
                              connection: RtcConnection(channelId: _activeChannelId),
                            ),
                          )
                        : Container(
                            width: 160,
                            height: 160,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
                            child: ClipOval(
                              child: widget.targetProfile.photoUrl != null
                                  ? Image.network(widget.targetProfile.photoUrl!, fit: BoxFit.cover)
                                  : Center(
                                      child: Text(
                                        widget.targetProfile.displayName.characters.first.toUpperCase(),
                                        style: const TextStyle(fontSize: 64, color: Colors.white70, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                            ),
                          ))
                    : const CircularProgressIndicator(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CallActionButton(
                    icon: Icons.videocam,
                    label: 'วิดีโอ',
                    color: const Color(0xFF00B900),
                    onTap: () {},
                  ),
                  const SizedBox(width: 32),
                  _CallActionButton(
                    icon: Icons.call_end,
                    label: 'วางสาย',
                    color: Colors.redAccent,
                    onTap: () {
                      _engine.leaveChannel();
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 32),
                  _CallActionButton(
                    icon: _micMuted ? Icons.mic_off : Icons.mic,
                    label: _micMuted ? 'ปลดปิดไมค์' : 'ปิดไมค์',
                    color: Colors.white10,
                    iconColor: Colors.white,
                    onTap: _toggleMute,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceContent() {
    final statusText = !_joined
        ? 'กำลังเชื่อมต่อ...'
        : _remoteUid == null
            ? 'กำลังโทรหา'
            : 'กำลังสนทนากับ';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF374049), Color(0xFF1F252B)],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                children: [
                  Text(statusText, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 12),
                  Text(
                    widget.targetProfile.displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  width: 160,
                  height: 160,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
                  child: ClipOval(
                    child: widget.targetProfile.photoUrl != null
                        ? Image.network(widget.targetProfile.photoUrl!, fit: BoxFit.cover)
                        : Center(
                            child: Text(
                              widget.targetProfile.displayName.characters.first.toUpperCase(),
                              style: const TextStyle(fontSize: 64, color: Colors.white70, fontWeight: FontWeight.w600),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CallActionButton(
                      icon: _speakerOn ? Icons.volume_up : Icons.volume_mute,
                      label: 'ลำโพง',
                      color: Colors.white10,
                      iconColor: Colors.white,
                      onTap: _toggleSpeaker,
                    ),
                    const SizedBox(width: 32),
                    _CallActionButton(
                      icon: _micMuted ? Icons.mic_off : Icons.mic,
                      label: _micMuted ? 'ปลดปิดไมค์' : 'ปิดไมค์',
                      color: Colors.white10,
                      iconColor: Colors.white,
                      onTap: _toggleMute,
                    ),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CallActionButton(
                    icon: Icons.call,
                    label: 'เสียง',
                    color: const Color(0xFF00B900),
                    onTap: () {},
                  ),
                  const SizedBox(width: 32),
                  _CallActionButton(
                    icon: Icons.call_end,
                    label: 'วางสาย',
                    color: Colors.redAccent,
                    onTap: () {
                      _engine.leaveChannel();
                      Navigator.of(context).pop();
                    },
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

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
            ),
            child: Icon(icon, color: iconColor, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
