'use client';
import { useEffect, useState, type FormEvent } from 'react';
import { apiGet, apiPost, apiPut, apiPatch, ApiError } from '@/lib/api';
import { PencilIcon, PowerOffIcon } from '@/components/ActionIcons';
import type { Technician } from '@/lib/types';

const EMPTY_ACCOUNT_FORM = { fullName: '', phone: '', email: '', password: '' };
const EMPTY_EDIT_FORM = { fullName: '', phone: '' };

export default function TechnicianManager() {
  const [technicians, setTechnicians] = useState<Technician[]>([]);
  const [accountForm, setAccountForm] = useState(EMPTY_ACCOUNT_FORM);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editForm, setEditForm] = useState(EMPTY_EDIT_FORM);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    setTechnicians(await apiGet<Technician[]>('/admin/technicians'));
  }

  useEffect(() => {
    load().catch((err) => setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ'));
  }, []);

  async function handleCreate(e: FormEvent) {
    e.preventDefault();
    setError(null);
    try {
      await apiPost('/admin/technicians', accountForm);
      setAccountForm(EMPTY_ACCOUNT_FORM);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'สร้างบัญชีช่างไม่สำเร็จ');
    }
  }

  function startEdit(tech: Technician) {
    setEditingId(tech.id);
    setEditForm({ fullName: tech.fullName, phone: tech.phone ?? '' });
  }

  async function handleUpdate(e: FormEvent) {
    e.preventDefault();
    if (!editingId) return;
    setError(null);
    try {
      await apiPut(`/admin/technicians/${editingId}`, editForm);
      setEditingId(null);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'บันทึกไม่สำเร็จ');
    }
  }

  async function handleDeactivate(id: number) {
    if (!confirm('ปิดใช้งานช่างคนนี้?')) return;
    try {
      await apiPatch(`/admin/technicians/${id}/deactivate`, {});
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'ปิดใช้งานไม่สำเร็จ');
    }
  }

  return (
    <div className="grid gap-4 md:grid-cols-[2fr_1fr]">
      <table className="w-full rounded-lg bg-white shadow-sm">
        <thead>
          <tr className="border-b text-left text-sm text-gray-500">
            <th className="p-3">ชื่อ</th>
            <th className="p-3">เบอร์โทร</th>
            <th className="p-3">อีเมล</th>
            <th className="p-3">สถานะ</th>
            <th className="p-3"></th>
          </tr>
        </thead>
        <tbody>
          {technicians.map((tech) =>
            editingId === tech.id ? (
              <tr key={tech.id} className="border-b text-sm last:border-0">
                <td className="p-2" colSpan={5}>
                  <form onSubmit={handleUpdate} className="flex flex-wrap items-center gap-2">
                    <input
                      required
                      value={editForm.fullName}
                      onChange={(e) => setEditForm({ ...editForm, fullName: e.target.value })}
                      className="rounded border border-gray-300 px-2 py-1"
                    />
                    <input
                      value={editForm.phone}
                      onChange={(e) => setEditForm({ ...editForm, phone: e.target.value })}
                      className="rounded border border-gray-300 px-2 py-1"
                    />
                    <button type="submit" className="rounded bg-brand px-3 py-1 text-white">
                      บันทึก
                    </button>
                    <button type="button" onClick={() => setEditingId(null)} className="rounded border px-3 py-1">
                      ยกเลิก
                    </button>
                  </form>
                </td>
              </tr>
            ) : (
              <tr key={tech.id} className="border-b text-sm last:border-0">
                <td className="p-3">{tech.fullName}</td>
                <td className="p-3">{tech.phone ?? '-'}</td>
                <td className="p-3">{tech.email ?? '-'}</td>
                <td className="whitespace-nowrap p-3">
                  <span
                    className={`rounded-full px-3 py-1 text-xs font-medium ${
                      tech.active ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'
                    }`}
                  >
                    {tech.active ? 'ใช้งานอยู่' : 'ปิดใช้งาน'}
                  </span>
                </td>
                <td className="space-x-2 whitespace-nowrap p-3">
                  <button
                    onClick={() => startEdit(tech)}
                    className="inline-flex items-center gap-1 whitespace-nowrap rounded-md bg-yellow-500 px-3 py-1.5 text-sm text-white hover:bg-yellow-600"
                  >
                    <PencilIcon />
                    แก้ไข
                  </button>
                  {tech.active && (
                    <button
                      onClick={() => handleDeactivate(tech.id)}
                      className="inline-flex items-center gap-1 whitespace-nowrap rounded-md bg-brand px-3 py-1.5 text-sm text-white hover:bg-brand-dark"
                    >
                      <PowerOffIcon />
                      ปิดใช้งาน
                    </button>
                  )}
                </td>
              </tr>
            ),
          )}
        </tbody>
      </table>

      <form onSubmit={handleCreate} className="space-y-3 rounded-lg bg-white p-4 shadow-sm">
        <h3 className="font-semibold">เพิ่มช่างใหม่</h3>
        {error && <p className="rounded bg-red-50 p-2 text-sm text-brand">{error}</p>}
        <input
          required
          placeholder="ชื่อ-นามสกุล"
          value={accountForm.fullName}
          onChange={(e) => setAccountForm({ ...accountForm, fullName: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <input
          placeholder="เบอร์โทร"
          value={accountForm.phone}
          onChange={(e) => setAccountForm({ ...accountForm, phone: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <input
          required
          type="email"
          placeholder="อีเมล (ใช้ล็อกอิน)"
          value={accountForm.email}
          onChange={(e) => setAccountForm({ ...accountForm, email: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <input
          required
          type="password"
          minLength={8}
          placeholder="รหัสผ่าน (อย่างน้อย 8 ตัว)"
          value={accountForm.password}
          onChange={(e) => setAccountForm({ ...accountForm, password: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <button type="submit" className="rounded bg-brand px-4 py-2 text-sm text-white hover:bg-brand-dark">
          เพิ่มช่าง
        </button>
      </form>
    </div>
  );
}
