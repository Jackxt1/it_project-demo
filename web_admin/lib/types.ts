export type BookingStatus = 'PENDING' | 'CONFIRMED' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED';

export interface BookingStatusHistory {
  id: number;
  status: string;
  note: string | null;
  changedByName: string | null;
  changedAt: string;
}

export interface Booking {
  id: number;
  userId: number;
  userFullName: string;
  serviceId: number;
  serviceName: string;
  productId: number | null;
  productName: string | null;
  technicianId: number | null;
  technicianName: string | null;
  bookingDate: string;
  timeSlot: string;
  status: BookingStatus;
  budget: number | null;
  imageUrl: string | null;
  quotePrice: number | null;
  totalAmount: number | null;
  paymentStatus: 'AWAITING_PAYMENT' | 'PENDING_REVIEW' | 'VERIFIED' | 'REJECTED';
  slipImageUrl: string | null;
  slipSubmittedAt: string | null;
  slipReviewedAt: string | null;
  slipReviewNote: string | null;
  notes: string | null;
  orderCode: string | null;
  vehicleId: number | null;
  vehicleBrandModel: string | null;
  vehicleLicensePlate: string | null;
  installArea: string | null;
  paymentType: string | null;
  paidAmount: number | null;
  createdAt: string;
  updatedAt: string;
  statusHistory: BookingStatusHistory[];
}

export interface Customer {
  id: number;
  fullName: string;
  email: string;
  phone: string | null;
  createdAt: string;
  vehicleBrandModel: string | null;
  vehicleLicensePlate: string | null;
}

export interface CustomerDetail extends Customer {
  bookings: Booking[];
}

export interface Technician {
  id: number;
  userId: number | null;
  fullName: string;
  phone: string | null;
  email: string | null;
  active: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface Service {
  id: number;
  name: string;
  description: string | null;
  basePrice: number;
  maxPerSlot: number;
  createdAt: string;
  updatedAt: string;
}

export interface Product {
  id: number;
  serviceId: number;
  serviceName: string;
  name: string;
  brand: string | null;
  grade: string | null;
  heatRejectionPct: number | null;
  uvRejectionPct: number | null;
  vltPct: number | null;
  price: number;
  description: string | null;
  imageUrl: string | null;
  active: boolean;
  stockQuantity: number | null;
  createdAt: string;
  updatedAt: string;
}

export interface ChatMessage {
  id: number;
  bookingId: number;
  senderType: string;
  senderId: number | null;
  senderName: string | null;
  message: string;
  createdAt: string;
  readAt: string | null;
}

export interface ChatInboxItem {
  bookingId: number;
  customerName: string;
  serviceName: string;
  lastMessage: string;
  lastMessageAt: string;
  unreadCount: number;
}

export interface DashboardSummary {
  bookingsToday: number;
  bookingsThisMonth: number;
  revenueToday: number;
  revenueThisMonth: number;
}

export interface BookingsByStatus {
  statusCounts: Record<string, number>;
}

export interface TrendPoint {
  label: string;
  count: number;
}

export interface BookingsTrend {
  points: TrendPoint[];
}

export interface CurrentUser {
  id: number;
  fullName: string;
  email: string;
  phone: string | null;
  profileImageUrl: string | null;
  role: string;
}

export interface Page<T> {
  content: T[];
  totalElements: number;
  totalPages: number;
  number: number;
}
