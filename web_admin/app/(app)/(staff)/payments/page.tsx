import PaymentSlipReview from './PaymentSlipReview';

export default function PaymentsPage() {
  return (
    <div>
      <h1 className="mb-4 text-xl font-bold text-brand-deep">ตรวจสอบสลิปการโอนเงิน</h1>
      <PaymentSlipReview />
    </div>
  );
}
