'use client';
import { useEffect, useState, type FormEvent } from 'react';
import { apiGet, apiPost, apiPut, apiDelete, ApiError } from '@/lib/api';
import type { Service } from '@/lib/types';

const EMPTY_FORM = { name: '', description: '', basePrice: '', maxPerSlot: '' };

export default function ServiceManager() {
  const [services, setServices] = useState<Service[]>([]);
  const [form, setForm] = useState(EMPTY_FORM);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    setServices(await apiGet<Service[]>('/services'));
  }

  useEffect(() => {
    load().catch((err) => setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ'));
  }, []);

  function startEdit(service: Service) {
    setEditingId(service.id);
    setForm({
      name: service.name,
      description: service.description ?? '',
      basePrice: String(service.basePrice),
      maxPerSlot: String(service.maxPerSlot),
    });
  }

  function resetForm() {
    setEditingId(null);
    setForm(EMPTY_FORM);
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    const payload = {
      name: form.name,
      description: form.description || null,
      basePrice: Number(form.basePrice),
      maxPerSlot: Number(form.maxPerSlot),
    };
    try {
      if (editingId) {
        await apiPut(`/services/${editingId}`, payload);
      } else {
        await apiPost('/services', payload);
      }
      resetForm();
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'บันทึกไม่สำเร็จ');
    }
  }

  async function handleDelete(id: number) {
    if (!confirm('ลบบริการนี้?')) return;
    try {
      await apiDelete(`/services/${id}`);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'ลบไม่สำเร็จ');
    }
  }

  return (
    <div className="grid gap-4 md:grid-cols-[2fr_1fr]">
      <table className="w-full rounded-lg bg-white shadow-sm">
        <thead>
          <tr className="border-b text-left text-sm text-gray-500">
            <th className="p-3">ชื่อบริการ</th>
            <th className="p-3">ราคาเริ่มต้น</th>
            <th className="p-3">คิวสูงสุด/ช่วงเวลา</th>
            <th className="p-3"></th>
          </tr>
        </thead>
        <tbody>
          {services.map((service) => (
            <tr key={service.id} className="border-b text-sm last:border-0">
              <td className="p-3">{service.name}</td>
              <td className="p-3">{service.basePrice.toLocaleString()} บาท</td>
              <td className="p-3">{service.maxPerSlot}</td>
              <td className="space-x-2 p-3">
                <button onClick={() => startEdit(service)} className="text-brand hover:underline">
                  แก้ไข
                </button>
                <button onClick={() => handleDelete(service.id)} className="text-red-600 hover:underline">
                  ลบ
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      <form onSubmit={handleSubmit} className="space-y-3 rounded-lg bg-white p-4 shadow-sm">
        <h3 className="font-semibold">{editingId ? 'แก้ไขบริการ' : 'เพิ่มบริการใหม่'}</h3>
        {error && <p className="rounded bg-red-50 p-2 text-sm text-brand">{error}</p>}
        <input
          required
          placeholder="ชื่อบริการ"
          value={form.name}
          onChange={(e) => setForm({ ...form, name: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <textarea
          placeholder="รายละเอียด"
          value={form.description}
          onChange={(e) => setForm({ ...form, description: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <input
          required
          type="number"
          min="0"
          placeholder="ราคาเริ่มต้น"
          value={form.basePrice}
          onChange={(e) => setForm({ ...form, basePrice: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <input
          required
          type="number"
          min="1"
          placeholder="คิวสูงสุดต่อช่วงเวลา"
          value={form.maxPerSlot}
          onChange={(e) => setForm({ ...form, maxPerSlot: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <div className="flex gap-2">
          <button type="submit" className="rounded bg-brand px-4 py-2 text-sm text-white hover:bg-brand-dark">
            {editingId ? 'บันทึก' : 'เพิ่ม'}
          </button>
          {editingId && (
            <button type="button" onClick={resetForm} className="rounded border border-gray-300 px-4 py-2 text-sm">
              ยกเลิก
            </button>
          )}
        </div>
      </form>
    </div>
  );
}
