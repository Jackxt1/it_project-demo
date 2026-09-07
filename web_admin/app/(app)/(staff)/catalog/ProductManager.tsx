'use client';
import { useEffect, useState, type FormEvent } from 'react';
import { apiGet, apiPost, apiPut, apiDelete, ApiError } from '@/lib/api';
import type { Product, Service } from '@/lib/types';

const EMPTY_FORM = {
  serviceId: '',
  name: '',
  brand: '',
  grade: '',
  heatRejectionPct: '',
  uvRejectionPct: '',
  vltPct: '',
  price: '',
  description: '',
  imageUrl: '',
  active: true,
};

function numOrNull(value: string): number | null {
  return value === '' ? null : Number(value);
}

export default function ProductManager() {
  const [products, setProducts] = useState<Product[]>([]);
  const [services, setServices] = useState<Service[]>([]);
  const [form, setForm] = useState(EMPTY_FORM);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [stockDrafts, setStockDrafts] = useState<Record<number, string>>({});
  const [error, setError] = useState<string | null>(null);

  async function load() {
    const [productList, serviceList] = await Promise.all([
      apiGet<Product[]>('/products?includeInactive=true'),
      apiGet<Service[]>('/services'),
    ]);
    setProducts(productList);
    setServices(serviceList);
  }

  useEffect(() => {
    load().catch((err) => setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ'));
  }, []);

  function startEdit(product: Product) {
    setEditingId(product.id);
    setForm({
      serviceId: String(product.serviceId),
      name: product.name,
      brand: product.brand ?? '',
      grade: product.grade ?? '',
      heatRejectionPct: product.heatRejectionPct === null ? '' : String(product.heatRejectionPct),
      uvRejectionPct: product.uvRejectionPct === null ? '' : String(product.uvRejectionPct),
      vltPct: product.vltPct === null ? '' : String(product.vltPct),
      price: String(product.price),
      description: product.description ?? '',
      imageUrl: product.imageUrl ?? '',
      active: product.active,
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
      serviceId: Number(form.serviceId),
      name: form.name,
      brand: form.brand || null,
      grade: form.grade || null,
      heatRejectionPct: numOrNull(form.heatRejectionPct),
      uvRejectionPct: numOrNull(form.uvRejectionPct),
      vltPct: numOrNull(form.vltPct),
      price: Number(form.price),
      description: form.description || null,
      imageUrl: form.imageUrl || null,
      active: form.active,
    };
    try {
      if (editingId) {
        await apiPut(`/products/${editingId}`, payload);
      } else {
        await apiPost('/products', payload);
      }
      resetForm();
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'บันทึกไม่สำเร็จ');
    }
  }

  async function handleDelete(id: number) {
    if (!confirm('ลบสินค้านี้?')) return;
    try {
      await apiDelete(`/products/${id}`);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'ลบไม่สำเร็จ');
    }
  }

  async function handleStockSave(id: number) {
    const raw = stockDrafts[id];
    if (raw === undefined) return;
    try {
      await apiPut(`/products/${id}/stock`, { stockQuantity: Number(raw) });
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'อัปเดตสต็อกไม่สำเร็จ');
    }
  }

  return (
    <div className="grid gap-4 md:grid-cols-[2fr_1fr]">
      <table className="w-full rounded-lg bg-white shadow-sm">
        <thead>
          <tr className="border-b text-left text-sm text-gray-500">
            <th className="p-3">สินค้า</th>
            <th className="p-3">ราคา</th>
            <th className="p-3">สถานะ</th>
            <th className="p-3">สต็อก</th>
            <th className="p-3"></th>
          </tr>
        </thead>
        <tbody>
          {products.map((product) => (
            <tr key={product.id} className="border-b text-sm last:border-0">
              <td className="p-3">
                {product.name}
                <div className="text-xs text-gray-400">{product.serviceName}</div>
              </td>
              <td className="p-3">{product.price.toLocaleString()} บาท</td>
              <td className="p-3">{product.active ? 'เปิดขาย' : 'ปิดขาย'}</td>
              <td className="p-3">
                <div className="flex items-center gap-1">
                  <input
                    type="number"
                    min="0"
                    placeholder={product.stockQuantity === null ? 'ไม่จำกัด' : String(product.stockQuantity)}
                    value={stockDrafts[product.id] ?? ''}
                    onChange={(e) => setStockDrafts({ ...stockDrafts, [product.id]: e.target.value })}
                    className="w-20 rounded border border-gray-300 px-2 py-1"
                  />
                  <button onClick={() => handleStockSave(product.id)} className="text-brand hover:underline">
                    บันทึก
                  </button>
                </div>
              </td>
              <td className="space-x-2 p-3">
                <button onClick={() => startEdit(product)} className="text-brand hover:underline">
                  แก้ไข
                </button>
                <button onClick={() => handleDelete(product.id)} className="text-red-600 hover:underline">
                  ลบ
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      <form onSubmit={handleSubmit} className="space-y-3 rounded-lg bg-white p-4 shadow-sm">
        <h3 className="font-semibold">{editingId ? 'แก้ไขสินค้า' : 'เพิ่มสินค้าใหม่'}</h3>
        {error && <p className="rounded bg-red-50 p-2 text-sm text-brand">{error}</p>}
        <select
          required
          value={form.serviceId}
          onChange={(e) => setForm({ ...form, serviceId: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        >
          <option value="">เลือกบริการ</option>
          {services.map((service) => (
            <option key={service.id} value={service.id}>
              {service.name}
            </option>
          ))}
        </select>
        <input
          required
          placeholder="ชื่อสินค้า"
          value={form.name}
          onChange={(e) => setForm({ ...form, name: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <input
          placeholder="แบรนด์"
          value={form.brand}
          onChange={(e) => setForm({ ...form, brand: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <input
          placeholder="เกรด"
          value={form.grade}
          onChange={(e) => setForm({ ...form, grade: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <input
          placeholder="URL รูปภาพ"
          value={form.imageUrl}
          onChange={(e) => setForm({ ...form, imageUrl: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <div className="grid grid-cols-3 gap-2">
          <input
            type="number"
            min="0"
            max="100"
            placeholder="% กันร้อน"
            value={form.heatRejectionPct}
            onChange={(e) => setForm({ ...form, heatRejectionPct: e.target.value })}
            className="w-full rounded border border-gray-300 px-2 py-2 text-sm"
          />
          <input
            type="number"
            min="0"
            max="100"
            placeholder="% กันยูวี"
            value={form.uvRejectionPct}
            onChange={(e) => setForm({ ...form, uvRejectionPct: e.target.value })}
            className="w-full rounded border border-gray-300 px-2 py-2 text-sm"
          />
          <input
            type="number"
            min="0"
            max="100"
            placeholder="% ความเข้ม (VLT)"
            value={form.vltPct}
            onChange={(e) => setForm({ ...form, vltPct: e.target.value })}
            className="w-full rounded border border-gray-300 px-2 py-2 text-sm"
          />
        </div>
        <input
          required
          type="number"
          min="0"
          placeholder="ราคา"
          value={form.price}
          onChange={(e) => setForm({ ...form, price: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <textarea
          placeholder="รายละเอียด"
          value={form.description}
          onChange={(e) => setForm({ ...form, description: e.target.value })}
          className="w-full rounded border border-gray-300 px-3 py-2"
        />
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.active}
            onChange={(e) => setForm({ ...form, active: e.target.checked })}
          />
          เปิดขาย
        </label>
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
