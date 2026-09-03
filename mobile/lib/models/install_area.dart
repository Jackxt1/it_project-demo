/// One choice in the "บริเวณที่ต้องการติดฟิล์ม" (film install area) picker —
/// shared between the booking flow's step 2 and the chatbot's film-service
/// branch so both offer the exact same options and `value`s sent to the
/// backend (`BookingDraft.installArea`).
class InstallAreaOption {
  const InstallAreaOption(this.label, this.value);
  final String label;
  final String value;
}

const List<InstallAreaOption> installAreaOptions = [
  InstallAreaOption('รอบคัน', 'FULL'),
  InstallAreaOption('กระจกหน้า-หลัง', 'FRONT_BACK'),
  InstallAreaOption('กระจกหน้า', 'FRONT'),
  InstallAreaOption('กระจกหลัง', 'BACK'),
];
