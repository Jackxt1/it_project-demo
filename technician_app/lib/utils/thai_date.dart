/// Thai date formatting helpers (Buddhist Era, no external intl locale
/// data needed since we only ever format Gregorian [DateTime]s to Thai
/// strings, never parse Thai text back).
library;

const List<String> monthsTh = [
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

const List<String> weekdaysThShort = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];

const List<String> weekdaysThLong = [
  'วันจันทร์',
  'วันอังคาร',
  'วันพุธ',
  'วันพฤหัสบดี',
  'วันศุกร์',
  'วันเสาร์',
  'วันอาทิตย์',
];

int buddhistYear(int gregorianYear) => gregorianYear + 543;

/// e.g. "วันพุธที่ 3 กันยายน 2569".
String thaiFullDate(DateTime date) {
  final weekday = weekdaysThLong[date.weekday - 1];
  return '$weekdayที่ ${date.day} ${monthsTh[date.month - 1]} ${buddhistYear(date.year)}';
}

/// e.g. "3 ก.ย. 2569" — compact form for list rows.
String thaiShortDate(DateTime date) {
  const shortMonths = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];
  return '${date.day} ${shortMonths[date.month - 1]} ${buddhistYear(date.year)}';
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
