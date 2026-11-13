/// Formats provider timestamps using the device's local time.
String formatMailDate(String value, {bool detailed = false}) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final now = DateTime.now();
  if (detailed) {
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minutes = parsed.minute.toString().padLeft(2, '0');
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year} · $hour:$minutes ${parsed.hour >= 12 ? 'PM' : 'AM'}';
  }
  if (parsed.year == now.year &&
      parsed.month == now.month &&
      parsed.day == now.day) {
    return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }
  return parsed.year == now.year
      ? '${months[parsed.month - 1]} ${parsed.day}'
      : '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
}
