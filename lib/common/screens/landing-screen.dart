// lib/common/screens/landing_screen.dart

// Claude's//
/* 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'create-id-screen.dart';

class _C {
  static const paper = Color(0xFFF1ECE2);
  static const paperDeep = Color(0xFFE9E3D5);
  static const card = Color(0xFFFBF8F1);
  static const ink = Color(0xFF151412);
  static const accent = Color(0xFFE8452C);
  static const muted = Color(0xFF6E685D);
  static const line = Color(0xFFCFC8B8);
  static const dimOnInk = Color(0xFFB4AEA1);
  static const lineOnInk = Color(0xFF3A3834);
}

class _T {
  static TextStyle serif(
    double size, {
    Color color = _C.ink,
    FontWeight w = FontWeight.w600,
    FontStyle style = FontStyle.normal,
    double h = 1.05,
    double ls = -0.5,
  }) =>
      GoogleFonts.fraunces(
        fontSize: size,
        color: color,
        fontWeight: w,
        fontStyle: style,
        height: h,
        letterSpacing: ls,
      );

  static TextStyle body(
    double size, {
    Color color = _C.ink,
    FontWeight w = FontWeight.w400,
    double h = 1.55,
  }) =>
      GoogleFonts.interTight(
        fontSize: size,
        color: color,
        fontWeight: w,
        height: h,
      );

  static TextStyle mono(
    double size, {
    Color color = _C.muted,
    FontWeight w = FontWeight.w500,
    double ls = 1.2,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        color: color,
        fontWeight: w,
        letterSpacing: ls,
      );
}

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _philosophyKey = GlobalKey();
  final _howKey = GlobalKey();
  final _wallKey = GlobalKey();

  void _goCreate() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateIdScreen()),
    );
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 980;
    final pad = wide ? 56.0 : (w >= 600 ? 36.0 : 20.0);
    final vPad = wide ? 120.0 : 72.0;

    return Scaffold(
      backgroundColor: _C.paper,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Band(
              color: _C.paper,
              pad: pad,
              vPad: 0,
              child: Column(
                children: [
                  _nav(wide),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: wide ? 88 : 48),
                    child: _hero(wide),
                  ),
                ],
              ),
            ),
            _marquee(),
            _Band(
              key: _philosophyKey,
              color: _C.ink,
              pad: pad,
              vPad: vPad,
              child: _philosophy(wide),
            ),
            _Band(
              key: _howKey,
              color: _C.paper,
              pad: pad,
              vPad: vPad,
              child: _how(wide),
            ),
            _Band(
              key: _wallKey,
              color: _C.paperDeep,
              pad: pad,
              vPad: vPad,
              child: _wall(wide),
            ),
            _Band(
              color: _C.accent,
              pad: pad,
              vPad: vPad,
              child: _finalCta(wide),
            ),
            _Band(
              color: _C.ink,
              pad: pad,
              vPad: 32,
              child: _footer(wide),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── NAV ─────────────────────────

  Widget _nav(bool wide) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.line)),
      ),
      child: Row(
        children: [
          const _Wordmark(),
          const Spacer(),
          if (wide) ...[
            _NavLink('PHILOSOPHY', () => _scrollTo(_philosophyKey)),
            const SizedBox(width: 32),
            _NavLink('HOW IT WORKS', () => _scrollTo(_howKey)),
            const SizedBox(width: 32),
            _NavLink('THE WALL', () => _scrollTo(_wallKey)),
            const SizedBox(width: 40),
          ],
          _CtaButton(label: 'Get Started', onTap: _goCreate, compact: true),
        ],
      ),
    );
  }

  // ───────────────────────── HERO ─────────────────────────

  Widget _hero(bool wide) {
    final headSize = wide ? 124.0 : 80.0;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('EVERY ROOM HAS A SECRET _ FOR STUDENTS & COLLEAGUES'),
        SizedBox(height: wide ? 28 : 20),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Say it.', style: _T.serif(headSize, w: FontWeight.w700)),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Sign nothing.',
            style: _T.serif(headSize,
                w: FontWeight.w400, style: FontStyle.italic, ls: -2),
          ),
        ),
        SizedBox(height: wide ? 36 : 28),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'ChatMate is a chat platform built around rooms, a class, a team, '
            'a circle of friends. Create your ID, join the rooms you belong to, '
            'and speak without your name attached. The sender of a message is '
            'never revealed to anyone.',
            style: _T.body(wide ? 18 : 16.5, color: _C.muted),
          ),
        ),
        SizedBox(height: wide ? 40 : 32),
        Wrap(
          spacing: 28,
          runSpacing: 18,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _CtaButton(label: 'Get Started', onTap: _goCreate),
            _GhostLink('See how it works', () => _scrollTo(_howKey)),
          ],
        ),
        const SizedBox(height: 28),
        Text('NO NAMES ON MESSAGES. EVER.', style: _T.mono(11)),
      ],
    );

    final right = Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Transform.rotate(
            angle: -0.03,
            child: const _SlipCard(
              tag: 'CONFESSION',
              room: 'ROOM · FINAL YEAR CSE',
              time: '11:42 PM',
              name: 'Rahul M.',
              body:
                  'I copied the lab record in second year. I have felt guilty ever since.',
              delayMs: 700,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: Transform.rotate(
            angle: 0.025,
            child: const _SlipCard(
              tag: 'TRUTH BOMB',
              room: 'ROOM · DESIGN TEAM',
              time: '9:05 AM',
              name: 'Priya S.',
              body:
                  'Your work is good. Your ten-minute introductions before it are not.',
              delayMs: 1500,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: wide ? 40 : 12),
            child: Transform.rotate(
              angle: -0.015,
              child: const _SlipCard(
                tag: 'PRANK',
                room: 'ROOM · HOSTEL BLOCK C',
                time: '2:17 AM',
                name: 'Karthik V.',
                body:
                    'Whoever keeps moving the warden\'s chair to the roof: respect.',
                delayMs: 2300,
              ),
            ),
          ),
        ),
      ],
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 11, child: left),
          const SizedBox(width: 64),
          Expanded(flex: 9, child: right),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [left, const SizedBox(height: 64), right],
    );
  }

  // ───────────────────────── MARQUEE ─────────────────────────

  Widget _marquee() {
    const words = [
      'Truth bombs',
      'Confessions',
      'Pranks',
      'Compliments',
      'Hard questions',
      'Unsigned',
    ];
    return Container(
      width: double.infinity,
      color: _C.ink,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: ClipRect(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++)
                for (final word in words) ...[
                  Text(
                    word,
                    style: _T.serif(24,
                        color: _C.paper,
                        w: FontWeight.w400,
                        style: FontStyle.italic,
                        ls: 0),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: SizedBox(
                      width: 8,
                      height: 8,
                      child: ColoredBox(color: _C.accent),
                    ),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── PHILOSOPHY ─────────────────────────

  Widget _philosophy(bool wide) {
    final statement = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('01 _ THE PHILOSOPHY'),
        const SizedBox(height: 24),
        Text.rich(
          TextSpan(
            style: _T.serif(wide ? 64 : 40, color: _C.paper, h: 1.08),
            children: [
              const TextSpan(text: 'A name makes people careful. '),
              TextSpan(
                text: 'A mask makes them honest.',
                style: _T.serif(wide ? 64 : 40,
                    color: _C.accent,
                    w: FontWeight.w400,
                    style: FontStyle.italic,
                    h: 1.08),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Most of what people want to say never gets said, because saying '
            'it costs them something. ChatMate removes that cost. Every message '
            'inside a room is delivered with no sender attached _ not to the '
            'other members, not to room admins, not to anyone. What is said '
            'stands on its own.',
            style: _T.body(17, color: _C.dimOnInk),
          ),
        ),
      ],
    );

    final principles = Column(
      children: [
        _principle('01', 'The sender is never exposed.',
            'No name, no profile link, no trace on a message. Nobody can see who wrote it.'),
        _principle('02', 'Identity is for belonging, not for messages.',
            'Your ID gets you into rooms. It never travels with what you say.'),
        _principle('03', 'Rooms keep it personal.',
            'Each room is its own space — a class, a team, a friend group _ shared only with the people who belong in it.'),
      ],
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: statement),
          const SizedBox(width: 80),
          Expanded(flex: 5, child: principles),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [statement, const SizedBox(height: 56), principles],
    );
  }

  Widget _principle(String no, String title, String desc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _C.lineOnInk)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(no, style: _T.mono(12, color: _C.accent, ls: 2)),
          const SizedBox(height: 12),
          Text(title, style: _T.serif(26, color: _C.paper, h: 1.15, ls: -0.3)),
          const SizedBox(height: 10),
          Text(desc, style: _T.body(15.5, color: _C.dimOnInk)),
        ],
      ),
    );
  }

  // ───────────────────────── HOW IT WORKS ─────────────────────────

  Widget _how(bool wide) {
    final steps = [
      _step('01', 'Create your ID',
          'Pick a username and set up your profile, the way you would on any social app. This is how you are found and added.'),
      _step('02', 'Join or get added to rooms',
          'A room is a dedicated chat for a group _ a class, a team, a circle of friends. Join one, or be added by someone already inside.'),
      _step('03', 'Say it, unsigned',
          'Write your message. It appears in the room with no name and no way to trace it back to you.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('02 _ HOW IT WORKS', color: _C.accent),
        const SizedBox(height: 24),
        Text(
          'Three steps.\nNo signature.',
          style: _T.serif(wide ? 72 : 44, h: 1.02),
        ),
        SizedBox(height: wide ? 72 : 48),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Expanded(child: steps[i]),
                if (i != steps.length - 1) const SizedBox(width: 48),
              ],
            ],
          )
        else
          Column(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                steps[i],
                if (i != steps.length - 1) const SizedBox(height: 40),
              ],
            ],
          ),
      ],
    );
  }

  Widget _step(String no, String title, String desc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _C.ink, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            no,
            style: _T.serif(64,
                color: _C.accent, w: FontWeight.w300, style: FontStyle.italic),
          ),
          const SizedBox(height: 20),
          Text(title, style: _T.serif(28, h: 1.15, ls: -0.3)),
          const SizedBox(height: 12),
          Text(desc, style: _T.body(16, color: _C.muted)),
        ],
      ),
    );
  }

  // ───────────────────────── THE WALL ─────────────────────────

  Widget _wall(bool wide) {
    const slips = [
      _SlipCard(
        tag: 'CONFESSION',
        room: 'ROOM · BATCH 2024',
        time: 'YESTERDAY',
        name: 'Ananya R.',
        body: 'I pretended to understand the project for three months. I never did.',
        instant: true,
      ),
      _SlipCard(
        tag: 'COMPLIMENT',
        room: 'ROOM · MARKETING',
        time: 'MON · 4:30 PM',
        name: 'Vikram T.',
        body: 'Whoever stayed late to fix the deck on Friday — we noticed.',
        instant: true,
      ),
      _SlipCard(
        tag: 'TRUTH BOMB',
        room: 'ROOM · STUDY GROUP',
        time: 'SUN · 8:12 PM',
        name: 'Meera N.',
        body: 'We do not need another meeting. We need someone to start working.',
        instant: true,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('03 _ THE WALL', color: _C.accent),
        const SizedBox(height: 24),
        Text(
          'Said out loud.\nSigned by no one.',
          style: _T.serif(wide ? 72 : 44, h: 1.02),
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'Confessions, truth bombs, pranks, compliments and the questions '
            'nobody asks. This is what a room looks like when nobody has to '
            'put a name to what they think.',
            style: _T.body(17, color: _C.muted),
          ),
        ),
        SizedBox(height: wide ? 72 : 48),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Transform.rotate(angle: -0.02, child: slips[0]),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Transform.rotate(angle: 0.02, child: slips[1]),
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Transform.rotate(angle: -0.012, child: slips[2]),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Transform.rotate(angle: -0.02, child: slips[0]),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: Transform.rotate(angle: 0.02, child: slips[1]),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Transform.rotate(angle: -0.012, child: slips[2]),
              ),
            ],
          ),
      ],
    );
  }

  // ───────────────────────── FINAL CTA ─────────────────────────

  Widget _finalCta(bool wide) {
    final headline = Text(
      'Make your ID.\nPick a room.\nSay it.',
      style: _T.serif(wide ? 88 : 52, color: _C.ink, h: 1.0, ls: -1.5),
    );

    final action = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(
            'It takes a minute to set up. After that, the room is yours — and '
            'so is everything you have been holding back.',
            style: _T.body(17, color: _C.ink),
          ),
        ),
        const SizedBox(height: 28),
        _CtaButton(label: 'Get Started', onTap: _goCreate, inverted: true),
      ],
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(flex: 6, child: headline),
          const SizedBox(width: 64),
          Expanded(flex: 4, child: action),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [headline, const SizedBox(height: 36), action],
    );
  }

  // ───────────────────────── FOOTER ─────────────────────────

  Widget _footer(bool wide) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 16,
      children: [
        const _Wordmark(light: true),
        Text(
          '© 2026 CHATMATE — WHERE TRUTHS UNRAVEL.',
          style: _T.mono(11, color: _C.dimOnInk),
        ),
      ],
    );
  }

  Widget _eyebrow(String text, {Color color = _C.accent}) {
    return Text(text, style: _T.mono(12, color: color, ls: 2));
  }
}

// ═════════════════════════ SHARED WIDGETS ═════════════════════════

class _Band extends StatelessWidget {
  final Color color;
  final double pad;
  final double vPad;
  final Widget child;

  const _Band({
    super.key,
    required this.color,
    required this.pad,
    required this.vPad,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: vPad),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: child,
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  final bool light;
  const _Wordmark({this.light = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'ChatMate',
          style: _T.serif(28,
              color: light ? _C.paper : _C.ink,
              w: FontWeight.w700,
              ls: -1,
              h: 1),
        ),
        const SizedBox(width: 3),
        const Padding(
          padding: EdgeInsets.only(bottom: 5),
          child: SizedBox(
            width: 8,
            height: 8,
            child: ColoredBox(color: _C.accent),
          ),
        ),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavLink(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(label, style: _T.mono(12, color: _C.ink, ls: 1.6)),
      ),
    );
  }
}

class _GhostLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostLink(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: _T.body(16, w: FontWeight.w600).copyWith(
                decoration: TextDecoration.underline,
                decorationColor: _C.accent,
                decorationThickness: 2,
              ),
        ),
      ),
    );
  }
}

class _CtaButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool compact;
  final bool inverted;

  const _CtaButton({
    required this.label,
    required this.onTap,
    this.compact = false,
    this.inverted = false,
  });

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color bg = widget.inverted
        ? (_hover ? _C.paper : _C.ink)
        : (_hover ? _C.accent : _C.ink);
    final Color fg = widget.inverted
        ? (_hover ? _C.ink : _C.paper)
        : _C.paper;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          color: bg,
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 18 : 28,
            vertical: widget.compact ? 12 : 18,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: _T.body(widget.compact ? 14 : 16,
                    color: fg, w: FontWeight.w600, h: 1.2),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: _hover ? 16 : 8,
              ),
              Icon(Icons.arrow_forward_rounded,
                  size: widget.compact ? 16 : 18, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

/// A printed "confession slip" with an animated redaction bar over the sender.
class _SlipCard extends StatelessWidget {
  final String tag;
  final String room;
  final String time;
  final String name;
  final String body;
  final int delayMs;
  final bool instant;

  const _SlipCard({
    required this.tag,
    required this.room,
    required this.time,
    required this.name,
    required this.body,
    this.delayMs = 0,
    this.instant = false,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _C.card,
          border: Border.all(color: _C.ink, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: _C.ink,
                  child: Text(tag,
                      style: _T.mono(10, color: _C.paper, ls: 1.6)),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(time,
                        style: _T.mono(10.5),
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              body,
              style: _T.serif(21,
                  w: FontWeight.w400, h: 1.3, ls: -0.2),
            ),
            const SizedBox(height: 20),
            Container(height: 1, color: _C.line),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('FROM', style: _T.mono(10.5, ls: 1.6)),
                const SizedBox(width: 12),
                _Redact(name: name, delayMs: delayMs, instant: instant),
              ],
            ),
            const SizedBox(height: 8),
            Text(room, style: _T.mono(10.5, color: _C.muted)),
          ],
        ),
      ),
    );
  }
}

class _Redact extends StatefulWidget {
  final String name;
  final int delayMs;
  final bool instant;

  const _Redact({
    required this.name,
    required this.delayMs,
    required this.instant,
  });

  @override
  State<_Redact> createState() => _RedactState();
}

class _RedactState extends State<_Redact> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.instant) {
      _c.value = 1;
    } else {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final bar = Curves.easeInOutCubic.transform(_c.value);
        final labelOpacity = ((_c.value - 0.75) / 0.25).clamp(0.0, 1.0);

        return SizedBox(
          width: 152,
          height: 26,
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.name,
                    style: _T.mono(13, color: _C.ink, ls: 0.4),
                  ),
                ),
              ),
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: bar,
                  child: const ColoredBox(color: _C.ink),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Opacity(
                    opacity: labelOpacity,
                    child: Text(
                      'SENDER HIDDEN',
                      style: _T.mono(9.5, color: _C.paper, ls: 1.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
*/

// DEEPSEEK'S
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'create-id-screen.dart';

class _C {
  // Light (paper) theme — green / black / white
  static const paper = Color(0xFFF6F8F5);
  static const paperDeep = Color(0xFFECF0E9);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0B0F0C);
  static const accent = Color(0xFF0E7A3A);
  static const accentBright = Color(0xFF1DB954);
  static const muted = Color(0xFF4A5450);
  static const line = Color(0xFFD5DCD3);

  // On-ink (dark) blocks
  static const dimOnInk = Color(0xFF9AA6A0);
  static const lineOnInk = Color(0xFF1F2A24);
  static const paperOnInk = Color(0xFFF2F5F3);
}

class _T {
  static TextStyle serif(
    double size, {
    Color color = _C.ink,
    FontWeight w = FontWeight.w600,
    FontStyle style = FontStyle.normal,
    double h = 1.05,
    double ls = -0.5,
  }) => GoogleFonts.fraunces(
    fontSize: size,
    color: color,
    fontWeight: w,
    fontStyle: style,
    height: h,
    letterSpacing: ls,
  );

  static TextStyle body(
    double size, {
    Color color = _C.ink,
    FontWeight w = FontWeight.w400,
    double h = 1.55,
  }) => GoogleFonts.interTight(
    fontSize: size,
    color: color,
    fontWeight: w,
    height: h,
  );

  static TextStyle mono(
    double size, {
    Color color = _C.muted,
    FontWeight w = FontWeight.w500,
    double ls = 1.2,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    color: color,
    fontWeight: w,
    letterSpacing: ls,
  );
}

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _philosophyKey = GlobalKey();
  final _howKey = GlobalKey();
  final _wallKey = GlobalKey();

  void _goCreate() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateIdScreen()));
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 980;
    final pad = wide ? 56.0 : (w >= 600 ? 36.0 : 20.0);
    final vPad = wide ? 120.0 : 72.0;

    return Scaffold(
      backgroundColor: _C.paper,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Band(
              color: _C.paper,
              pad: pad,
              vPad: 0,
              child: Column(
                children: [
                  _nav(wide),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: wide ? 88 : 48),
                    child: _hero(wide),
                  ),
                ],
              ),
            ),
            _marquee(),
            _Band(
              key: _philosophyKey,
              color: _C.ink,
              pad: pad,
              vPad: vPad,
              child: _philosophy(wide),
            ),
            _Band(
              key: _howKey,
              color: _C.paper,
              pad: pad,
              vPad: vPad,
              child: _how(wide),
            ),
            _Band(
              key: _wallKey,
              color: _C.paperDeep,
              pad: pad,
              vPad: vPad,
              child: _wall(wide),
            ),
            _Band(
              color: _C.accent,
              pad: pad,
              vPad: vPad,
              child: _finalCta(wide),
            ),
            _Band(color: _C.ink, pad: pad, vPad: 32, child: _footer(wide)),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── NAV ─────────────────────────

  Widget _nav(bool wide) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.line)),
      ),
      child: Row(
        children: [
          const _Wordmark(),
          const Spacer(),
          if (wide) ...[
            _NavLink('PHILOSOPHY', () => _scrollTo(_philosophyKey)),
            const SizedBox(width: 32),
            _NavLink('HOW IT WORKS', () => _scrollTo(_howKey)),
            const SizedBox(width: 32),
            _NavLink('THE WALL', () => _scrollTo(_wallKey)),
            const SizedBox(width: 40),
          ],
          _CtaButton(label: 'Get Started', onTap: _goCreate, compact: true),
        ],
      ),
    );
  }

  // ───────────────────────── HERO ─────────────────────────

  Widget _hero(bool wide) {
    final headSize = wide ? 124.0 : 80.0;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('EVERY ROOM HAS A SECRET _ FOR STUDENTS & COLLEAGUES'),
        SizedBox(height: wide ? 28 : 20),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Say it.', style: _T.serif(headSize, w: FontWeight.w700)),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Sign nothing.',
            style: _T.serif(
              headSize,
              w: FontWeight.w400,
              style: FontStyle.italic,
              ls: -2,
            ),
          ),
        ),
        SizedBox(height: wide ? 36 : 28),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'ChatMate is a chat platform built around rooms, a class, a team, '
            'a circle of friends. Create your ID, join the rooms you belong to, '
            'and speak without your name attached. The sender of a message is '
            'never revealed to anyone.',
            style: _T.body(wide ? 18 : 16.5, color: _C.muted),
          ),
        ),
        SizedBox(height: wide ? 40 : 32),
        Wrap(
          spacing: 28,
          runSpacing: 18,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _CtaButton(label: 'Get Started', onTap: _goCreate),
            _GhostLink('See how it works', () => _scrollTo(_howKey)),
          ],
        ),
        const SizedBox(height: 28),
        Text('NO NAMES ON MESSAGES. EVER.', style: _T.mono(11)),
      ],
    );

    final right = Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Transform.rotate(
            angle: -0.03,
            child: const _SlipCard(
              tag: 'CONFESSION',
              room: 'ROOM · FINAL YEAR CSE',
              time: '11:42 PM',
              name: 'Rahul M.',
              body:
                  'I copied the lab record in second year. I have felt guilty ever since.',
              delayMs: 700,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: Transform.rotate(
            angle: 0.025,
            child: const _SlipCard(
              tag: 'TRUTH BOMB',
              room: 'ROOM · DESIGN TEAM',
              time: '9:05 AM',
              name: 'Priya S.',
              body:
                  'Your work is good. Your ten-minute introductions before it are not.',
              delayMs: 1500,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: wide ? 40 : 12),
            child: Transform.rotate(
              angle: -0.015,
              child: const _SlipCard(
                tag: 'PRANK',
                room: 'ROOM · HOSTEL BLOCK C',
                time: '2:17 AM',
                name: 'Karthik V.',
                body:
                    'Whoever keeps moving the warden\'s chair to the roof: respect.',
                delayMs: 2300,
              ),
            ),
          ),
        ),
      ],
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 11, child: left),
          const SizedBox(width: 64),
          Expanded(flex: 9, child: right),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [left, const SizedBox(height: 64), right],
    );
  }

  // ───────────────────────── MARQUEE ─────────────────────────

  Widget _marquee() {
    const words = [
      'Truth bombs',
      'Confessions',
      'Pranks',
      'Compliments',
      'Hard questions',
      'Unsigned',
    ];
    return Container(
      width: double.infinity,
      color: _C.ink,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: ClipRect(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++)
                for (final word in words) ...[
                  Text(
                    word,
                    style: _T.serif(
                      24,
                      color: _C.paperOnInk,
                      w: FontWeight.w400,
                      style: FontStyle.italic,
                      ls: 0,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: SizedBox(
                      width: 8,
                      height: 8,
                      child: ColoredBox(color: _C.accentBright),
                    ),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── PHILOSOPHY ─────────────────────────

  Widget _philosophy(bool wide) {
    final statement = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('01 _ THE PHILOSOPHY'),
        const SizedBox(height: 24),
        Text.rich(
          TextSpan(
            style: _T.serif(wide ? 64 : 40, color: _C.paperOnInk, h: 1.08),
            children: [
              const TextSpan(text: 'A name makes people careful. '),
              TextSpan(
                text: 'A mask makes them honest.',
                style: _T.serif(
                  wide ? 64 : 40,
                  color: _C.accentBright,
                  w: FontWeight.w400,
                  style: FontStyle.italic,
                  h: 1.08,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Most of what people want to say never gets said, because saying '
            'it costs them something. ChatMate removes that cost. Every message '
            'inside a room is delivered with no sender attached _ not to the '
            'other members, not to room admins, not to anyone. What is said '
            'stands on its own.',
            style: _T.body(17, color: _C.dimOnInk),
          ),
        ),
      ],
    );

    final principles = Column(
      children: [
        _principle(
          '01',
          'The sender is never exposed.',
          'No name, no profile link, no trace on a message. Nobody can see who wrote it.',
        ),
        _principle(
          '02',
          'Identity is for belonging, not for messages.',
          'Your ID gets you into rooms. It never travels with what you say.',
        ),
        _principle(
          '03',
          'Rooms keep it personal.',
          'Each room is its own space — a class, a team, a friend group _ shared only with the people who belong in it.',
        ),
      ],
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: statement),
          const SizedBox(width: 80),
          Expanded(flex: 5, child: principles),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [statement, const SizedBox(height: 56), principles],
    );
  }

  Widget _principle(String no, String title, String desc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _C.lineOnInk)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(no, style: _T.mono(12, color: _C.accentBright, ls: 2)),
          const SizedBox(height: 12),
          Text(
            title,
            style: _T.serif(26, color: _C.paperOnInk, h: 1.15, ls: -0.3),
          ),
          const SizedBox(height: 10),
          Text(desc, style: _T.body(15.5, color: _C.dimOnInk)),
        ],
      ),
    );
  }

  // ───────────────────────── HOW IT WORKS ─────────────────────────

  Widget _how(bool wide) {
    final steps = [
      _step(
        '01',
        'Create your ID',
        'Pick a username and set up your profile, the way you would on any social app. This is how you are found and added.',
      ),
      _step(
        '02',
        'Join or get added to rooms',
        'A room is a dedicated chat for a group _ a class, a team, a circle of friends. Join one, or be added by someone already inside.',
      ),
      _step(
        '03',
        'Say it, unsigned',
        'Write your message. It appears in the room with no name and no way to trace it back to you.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('02 _ HOW IT WORKS', color: _C.accent),
        const SizedBox(height: 24),
        Text(
          'Three steps.\nNo signature.',
          style: _T.serif(wide ? 72 : 44, h: 1.02),
        ),
        SizedBox(height: wide ? 72 : 48),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Expanded(child: steps[i]),
                if (i != steps.length - 1) const SizedBox(width: 48),
              ],
            ],
          )
        else
          Column(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                steps[i],
                if (i != steps.length - 1) const SizedBox(height: 40),
              ],
            ],
          ),
      ],
    );
  }

  Widget _step(String no, String title, String desc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _C.ink, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            no,
            style: _T.serif(
              64,
              color: _C.accent,
              w: FontWeight.w300,
              style: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
          Text(title, style: _T.serif(28, h: 1.15, ls: -0.3)),
          const SizedBox(height: 12),
          Text(desc, style: _T.body(16, color: _C.muted)),
        ],
      ),
    );
  }

  // ───────────────────────── THE WALL ─────────────────────────

  Widget _wall(bool wide) {
    const slips = [
      _SlipCard(
        tag: 'CONFESSION',
        room: 'ROOM · BATCH 2024',
        time: 'YESTERDAY',
        name: 'Ananya R.',
        body:
            'I pretended to understand the project for three months. I never did.',
        instant: true,
      ),
      _SlipCard(
        tag: 'COMPLIMENT',
        room: 'ROOM · MARKETING',
        time: 'MON · 4:30 PM',
        name: 'Vikram T.',
        body: 'Whoever stayed late to fix the deck on Friday — we noticed.',
        instant: true,
      ),
      _SlipCard(
        tag: 'TRUTH BOMB',
        room: 'ROOM · STUDY GROUP',
        time: 'SUN · 8:12 PM',
        name: 'Meera N.',
        body:
            'We do not need another meeting. We need someone to start working.',
        instant: true,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('03 _ THE WALL', color: _C.accent),
        const SizedBox(height: 24),
        Text(
          'Said out loud.\nSigned by no one.',
          style: _T.serif(wide ? 72 : 44, h: 1.02),
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'Confessions, truth bombs, pranks, compliments and the questions '
            'nobody asks. This is what a room looks like when nobody has to '
            'put a name to what they think.',
            style: _T.body(17, color: _C.muted),
          ),
        ),
        SizedBox(height: wide ? 72 : 48),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Transform.rotate(angle: -0.02, child: slips[0])),
              const SizedBox(width: 28),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Transform.rotate(angle: 0.02, child: slips[1]),
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Transform.rotate(angle: -0.012, child: slips[2]),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Transform.rotate(angle: -0.02, child: slips[0]),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: Transform.rotate(angle: 0.02, child: slips[1]),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Transform.rotate(angle: -0.012, child: slips[2]),
              ),
            ],
          ),
      ],
    );
  }

  // ───────────────────────── FINAL CTA ─────────────────────────

  Widget _finalCta(bool wide) {
    final headline = Text(
      'Make your ID.\nPick a room.\nSay it.',
      style: _T.serif(wide ? 88 : 52, color: _C.paperOnInk, h: 1.0, ls: -1.5),
    );

    final action = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(
            'It takes a minute to set up. After that, the room is yours — and '
            'so is everything you have been holding back.',
            style: _T.body(17, color: _C.paperOnInk),
          ),
        ),
        const SizedBox(height: 28),
        _CtaButton(label: 'Get Started', onTap: _goCreate, inverted: true),
      ],
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(flex: 6, child: headline),
          const SizedBox(width: 64),
          Expanded(flex: 4, child: action),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [headline, const SizedBox(height: 36), action],
    );
  }

  // ───────────────────────── FOOTER ─────────────────────────

  Widget _footer(bool wide) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 16,
      children: [
        const _Wordmark(light: true),
        Text(
          '© 2026 CHATMATE — WHERE TRUTHS UNRAVEL.',
          style: _T.mono(11, color: _C.dimOnInk),
        ),
      ],
    );
  }

  Widget _eyebrow(String text, {Color color = _C.accent}) {
    return Text(text, style: _T.mono(12, color: color, ls: 2));
  }
}

// ═════════════════════════ SHARED WIDGETS ═════════════════════════

class _Band extends StatelessWidget {
  final Color color;
  final double pad;
  final double vPad;
  final Widget child;

  const _Band({
    super.key,
    required this.color,
    required this.pad,
    required this.vPad,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: vPad),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: child,
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  final bool light;
  const _Wordmark({this.light = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'ChatMate',
          style: _T.serif(
            28,
            color: light ? _C.paperOnInk : _C.ink,
            w: FontWeight.w700,
            ls: -1,
            h: 1,
          ),
        ),
        const SizedBox(width: 3),
        const Padding(
          padding: EdgeInsets.only(bottom: 5),
          child: SizedBox(
            width: 8,
            height: 8,
            child: ColoredBox(color: _C.accentBright),
          ),
        ),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavLink(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(label, style: _T.mono(12, color: _C.ink, ls: 1.6)),
      ),
    );
  }
}

class _GhostLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostLink(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: _T
              .body(16, w: FontWeight.w600)
              .copyWith(
                decoration: TextDecoration.underline,
                decorationColor: _C.accentBright,
                decorationThickness: 2,
              ),
        ),
      ),
    );
  }
}

class _CtaButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool compact;
  final bool inverted;

  const _CtaButton({
    required this.label,
    required this.onTap,
    this.compact = false,
    this.inverted = false,
  });

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color bg = widget.inverted
        ? (_hover ? _C.paper : _C.ink)
        : (_hover ? _C.accentBright : _C.ink);
    final Color fg = widget.inverted
        ? (_hover ? _C.ink : _C.paper)
        : _C.paperOnInk;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          color: bg,
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 18 : 28,
            vertical: widget.compact ? 12 : 18,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: _T.body(
                  widget.compact ? 14 : 16,
                  color: fg,
                  w: FontWeight.w600,
                  h: 1.2,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: _hover ? 16 : 8,
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: widget.compact ? 16 : 18,
                color: fg,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A printed "confession slip" with an animated redaction bar over the sender.
class _SlipCard extends StatelessWidget {
  final String tag;
  final String room;
  final String time;
  final String name;
  final String body;
  final int delayMs;
  final bool instant;

  const _SlipCard({
    required this.tag,
    required this.room,
    required this.time,
    required this.name,
    required this.body,
    this.delayMs = 0,
    this.instant = false,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _C.card,
          border: Border.all(color: _C.ink, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  color: _C.ink,
                  child: Text(
                    tag,
                    style: _T.mono(10, color: _C.paperOnInk, ls: 1.6),
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      time,
                      style: _T.mono(10.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              body,
              style: _T.serif(21, w: FontWeight.w400, h: 1.3, ls: -0.2),
            ),
            const SizedBox(height: 20),
            Container(height: 1, color: _C.line),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('FROM', style: _T.mono(10.5, ls: 1.6)),
                const SizedBox(width: 12),
                _Redact(name: name, delayMs: delayMs, instant: instant),
              ],
            ),
            const SizedBox(height: 8),
            Text(room, style: _T.mono(10.5, color: _C.muted)),
          ],
        ),
      ),
    );
  }
}

class _Redact extends StatefulWidget {
  final String name;
  final int delayMs;
  final bool instant;

  const _Redact({
    required this.name,
    required this.delayMs,
    required this.instant,
  });

  @override
  State<_Redact> createState() => _RedactState();
}

class _RedactState extends State<_Redact> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.instant) {
      _c.value = 1;
    } else {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final bar = Curves.easeInOutCubic.transform(_c.value);
        final labelOpacity = ((_c.value - 0.75) / 0.25).clamp(0.0, 1.0);

        return SizedBox(
          width: 152,
          height: 26,
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.name,
                    style: _T.mono(13, color: _C.ink, ls: 0.4),
                  ),
                ),
              ),
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: bar,
                  child: const ColoredBox(color: _C.ink),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Opacity(
                    opacity: labelOpacity,
                    child: Text(
                      'SENDER HIDDEN',
                      style: _T.mono(9.5, color: _C.paperOnInk, ls: 1.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
