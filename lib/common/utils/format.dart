// lib/common/utils/format.dart

String _two(int value) => value.toString().padLeft(2, '0');

String clockTime(DateTime value) => '${_two(value.hour)}:${_two(value.minute)}';

String shortDate(DateTime? value) {
  if (value == null) return '';
  return '${value.year}-${_two(value.month)}-${_two(value.day)}';
}

String dayLabel(DateTime value) {
  const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${days[value.weekday - 1]} ${value.day} ${months[value.month - 1]}';
}

String relativeTime(DateTime? value) {
  if (value == null) return '';
  final now = DateTime.now();
  final diff = now.difference(value);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return shortDate(value);
}
