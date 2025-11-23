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
  bool _videoMuted = false;
  late final String _activeToken;
  late final String _activeChannelId;
  bool _incomingAccepted = false;

  // Agora App ID
  static const String appId = '37050f5308fd450ba070b53c01596c06';
  // ตัวอย่าง token/channel (ใช้เฉพาะกรณีไม่มีข้อมูลจริง)
  static const String _sampleToken = '007eJxTYLBpXsPNP2n6WtbV7V/u3zl9zpC1hWGv6Zv4nZsNV5mK9qUqMBibG5gapJkaG1ikpZiYGiQlGpgbJJkaJxsYmlqaJRuYsXopZDYEMjKwn+tmZGRgZWBkYGIA8RkYADzNG2k=';
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
          print('Agora: onJoinChannelSuccess channel=${connection.channelId} uid=${connection.localUid}');
          setState(() {
            _joined = true;
          });
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          print('Agora: onUserJoined remoteUid=$remoteUid');
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (connection, remoteUid, reason) {
          print('Agora: onUserOffline remoteUid=$remoteUid reason=$reason');
          setState(() {
            _remoteUid = null;
          });
        },
        onError: (err, msg) {
          print('Agora: onError code=$err msg=$msg');
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
      child: Stack(
        children: [
          // Remote video (full screen)
          Positioned.fill(child: remoteVideoView),
          // Local video (small corner)
          Positioned(
            top: 40,
            right: 20,
            child: SafeArea(
              child: SizedBox(
                width: 100,
                height: 150,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: localVideoView,
                ),
              ),
            ),
          ),
          // Controls
          _buildCallControls(statusText),
        ],
      ),
    );
  }

  Widget _buildVoiceContent() {
    final statusText = !_joined
        ? 'กำลังเชื่อมต่อ...'
        : _remoteUid == null
            ? 'กำลังโทรหา'
            : 'กำลังสนทนากับ';

    return _buildCallUI(
      statusText: statusText,
      centerContent: _buildCallingStatus(),
      bottomControls: _buildVoiceCallButtons(),
    );
  }

  Widget _buildCallUI({
    required String statusText,
    required Widget centerContent,
    required Widget bottomControls,
  }) {
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
            centerContent,
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: bottomControls,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallingStatus() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
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
        if (_remoteUid == null) const CircularProgressIndicator(color: Colors.white),
      ],
    );
  }

  Widget _buildCallControls(String statusText) {
    return _buildCallUI(
      statusText: statusText,
      centerContent: const SizedBox.shrink(), // Center is covered by video
      bottomControls: _buildVideoCallButtons(),
    );
  }
  
  Widget get localVideoView {
    if (_joined && !_videoMuted) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    }
    return Container(color: Colors.grey[800], child: const Center(child: Text('คุณปิดกล้อง', style: TextStyle(color: Colors.white))));
  }

  Widget get remoteVideoView {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(rtcEngine: _engine, canvas: VideoCanvas(uid: _remoteUid), connection: RtcConnection(channelId: _activeChannelId)),
      );
    }
    return Container(color: Colors.grey[900], child: Center(child: Text('กำลังรอคู่สนทนา...', style: TextStyle(color: Colors.white))));
  }

  void _toggleVideo() {
    _engine.muteLocalVideoStream(!_videoMuted);
    setState(() => _videoMuted = !_videoMuted);
  }

  Widget _buildVideoCallButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CallActionButton(
          icon: _videoMuted ? Icons.videocam_off : Icons.videocam,
          label: _videoMuted ? 'เปิดกล้อง' : 'ปิดกล้อง',
          color: Colors.white24,
          onTap: _toggleVideo,
        ),
        const SizedBox(width: 24),
        _CallActionButton(
          icon: Icons.call_end,
          label: 'วางสาย',
          color: Colors.redAccent,
          onTap: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 24),
        _CallActionButton(
          icon: _micMuted ? Icons.mic_off : Icons.mic,
          label: _micMuted ? 'เปิดไมค์' : 'ปิดไมค์',
          color: Colors.white24,
          onTap: _toggleMute,
        ),
      ],
    );
  }

  Widget _buildVoiceCallButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CallActionButton(
          icon: _speakerOn ? Icons.volume_up : Icons.volume_down,
          label: 'ลำโพง',
          color: Colors.white24,
          onTap: _toggleSpeaker,
        ),
        const SizedBox(width: 24),
        _CallActionButton(
          icon: Icons.call_end,
          label: 'วางสาย',
          color: Colors.redAccent,
          onTap: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 24),
        _CallActionButton(
          icon: _micMuted ? Icons.mic_off : Icons.mic,
          label: _micMuted ? 'เปิดไมค์' : 'ปิดไมค์',
          color: Colors.white24,
          onTap: _toggleMute,
        ),
      ],
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
      mainAxisSize: MainAxisSize.min,
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
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}
