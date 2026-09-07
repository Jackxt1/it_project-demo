import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/technician_booking_service.dart';
import '../api/technician_queue_socket.dart';
import '../models/booking.dart';

/// Single shared source of truth for "all bookings assigned to me", fetched
/// once from `GET /api/technician/bookings/me` and reused by the home
/// (today's queue), history, and calendar screens — the backend endpoint
/// has no server-side filtering, so every screen filters this same list
/// client-side instead of issuing its own request.
///
/// Also owns the live STOMP subscription (see [connectLive]) that pushes a
/// newly-assigned job into [bookings] the moment an admin assigns it,
/// instead of the technician only finding out on their next manual refresh.
class TechnicianQueueController extends ChangeNotifier {
  TechnicianQueueController();

  static TechnicianQueueController instance = TechnicianQueueController();

  List<Booking> _bookings = const [];
  List<Booking> get bookings => _bookings;

  bool _loading = false;
  bool get loading => _loading;

  bool _loadedOnce = false;
  bool get loadedOnce => _loadedOnce;

  String? _error;
  String? get error => _error;

  TechnicianQueueSocketConnector? _socket;
  final StreamController<Booking> _newJobController = StreamController<Booking>.broadcast();

  /// Fires every time the live socket delivers a newly-assigned (or
  /// reassigned) job — [MainShell] listens to this to pop a toast, separate
  /// from the [bookings] list update itself so the UI can tell "a fresh
  /// push happened" apart from "the list was reloaded from a refresh".
  Stream<Booking> get onNewJobAssigned => _newJobController.stream;

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await TechnicianBookingService.instance.fetchMyQueue();
      data.sort((a, b) {
        final byDate = a.bookingDate.compareTo(b.bookingDate);
        if (byDate != 0) return byDate;
        return a.timeSlot.compareTo(b.timeSlot);
      });
      _bookings = data;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'โหลดข้อมูลงานไม่สำเร็จ';
    } finally {
      _loading = false;
      _loadedOnce = true;
      notifyListeners();
    }
  }

  /// Swaps in a freshly-updated booking (e.g. after a status change) without
  /// a full re-fetch, so the queue/history/calendar screens reflect it
  /// immediately when the user backs out of the job detail screen.
  void replace(Booking updated) {
    _bookings = [
      for (final b in _bookings) b.id == updated.id ? updated : b,
    ];
    notifyListeners();
  }

  /// Inserts or updates [booking] in [bookings] and re-sorts, then emits it
  /// on [onNewJobAssigned]. Used both by the live socket (see [connectLive])
  /// and directly by tests.
  void upsert(Booking booking) {
    final exists = _bookings.any((b) => b.id == booking.id);
    _bookings = exists
        ? [for (final b in _bookings) b.id == booking.id ? booking : b]
        : [..._bookings, booking];
    _bookings.sort((a, b) {
      final byDate = a.bookingDate.compareTo(b.bookingDate);
      if (byDate != 0) return byDate;
      return a.timeSlot.compareTo(b.timeSlot);
    });
    notifyListeners();
    _newJobController.add(booking);
  }

  /// Opens the live STOMP subscription for [technicianUserId] so a job the
  /// backend assigns to this technician while the app is open shows up
  /// immediately instead of only after the next manual refresh/relaunch.
  /// Safe to call again (e.g. on re-login) — replaces any existing socket.
  ///
  /// [connectorOverride] lets tests inject a fake connector instead of
  /// opening a real socket.
  void connectLive(int technicianUserId, {TechnicianQueueSocketConnector? connectorOverride}) {
    _socket?.dispose();
    final socket = connectorOverride ?? StompTechnicianQueueSocketConnector();
    _socket = socket;
    socket.connect(
      technicianUserId: technicianUserId,
      onBookingAssigned: upsert,
    );
  }

  /// Tears down the live socket — call on logout/sign-out so a stale
  /// connection doesn't keep pushing a previous technician's assignments.
  void disconnectLive() {
    _socket?.dispose();
    _socket = null;
  }

  /// Clears cached state on logout so a different technician signing in on
  /// the same device never briefly sees the previous technician's jobs.
  void reset() {
    disconnectLive();
    _bookings = const [];
    _loadedOnce = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnectLive();
    _newJobController.close();
    super.dispose();
  }
}
