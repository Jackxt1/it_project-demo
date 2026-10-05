'use client';
import { useEffect, useMemo, useState } from 'react';
import { apiGet, apiPost, apiPut, apiDelete, ApiError } from '@/lib/api';
import { PencilIcon, TrashIcon } from '@/components/ActionIcons';
import { formatBaht } from '@/lib/format';
import type { Product, Service } from '@/lib/types';
import ProductFormModal, {
  EMPTY_PRODUCT_FORM,
  toFormValues,
  type ProductFormValues,
} from './ProductFormModal';

function numOrNull(value: string): number | null {
  return value.trim() === '' ? null : Number(value);
}

export default function ProductManager() {
  const [products, setProducts] = useState<Product[]>([]);
  const [services, setServices] = useState<Service[]>([]);
  const [activeServiceId, setActiveServiceId] = useState<number | null>(null);
  const [search, setSearch] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const [editing, setEditing] = useState<Product | null>(null);
  const [creating, setCreating] = useState(false);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  async function load() {
    const [productList, serviceList] = await Promise.all([
      apiGet<Product[]>('/products?includeInactive=true'),
      apiGet<Service[]>('/services'),
    ]);
    setProducts(productList);
    setServices(serviceList);
    setActiveServiceId((current) => current ?? serviceList[0]?.id ?? null);
  }

  useEffect(() => {
    load()
      .catch((err) => setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ'))
      .finally(() => setLoading(false));
  }, []);

  const countByService = useMemo(() => {
    const counts = new Map<number, number>();
    for (const product of products) {
      counts.set(product.serviceId, (counts.get(product.serviceId) ?? 0) + 1);
    }
    return counts;
  }, [products]);

  const visible = useMemo(() => {
    const term = search.trim().toLowerCase();
    return products
      .filter((p) => p.serviceId === activeServiceId)
      .filter((p) =>
        term === ''
          ? true
          : [p.name, p.brand, p.grade].filter(Boolean).some((v) => v!.toLowerCase().includes(term)),
      );
  }, [products, activeServiceId, search]);

  const activeService = services.find((s) => s.id === activeServiceId) ?? null;

  async function handleSubmit(values: ProductFormValues) {
    if (activeServiceId == null) return;
    setSaving(true);
    setFormError(null);
    const payload = {
      serviceId: editing ? editing.serviceId : activeServiceId,
      name: values.name,
      brand: values.brand || null,
      grade: values.grade || null,
      heatRejectionPct: numOrNull(values.heatRejectionPct),
      uvRejectionPct: numOrNull(values.uvRejectionPct),
      vltPct: numOrNull(values.vltPct),
      price: Number(values.price),
      description: values.description || null,
      imageUrl: values.imageUrl || null,
      active: values.active,
    };
    try {
      if (editing) {
        await apiPut(`/products/${editing.id}`, payload);
      } else {
        await apiPost('/products', payload);
      }
      setEditing(null);
      setCreating(false);
      await load();
    } catch (err) {
      setFormError(err instanceof ApiError ? err.message : 'บันทึกไม่สำเร็จ');
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(product: Product) {
    if (!confirm(`ลบ "${product.name}" ออกจากรายการสินค้า?`)) return;
    try {
      await apiDelete(`/products/${product.id}`);
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'ลบไม่สำเร็จ');
    }
  }

  if (loading) return <p className="text-sm text-gray-500">กำลังโหลด...</p>;

  return (
    <div>
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold text-brand-deep">สินค้าและราคา</h1>
        <button
          type="button"
          onClick={() => {
            setCreating(true);
            setFormError(null);
          }}
          disabled={activeServiceId == null}
          className="flex items-center gap-2 rounded-xl bg-brand-dark px-4 py-2 text-sm font-bold text-white hover:bg-brand disabled:opacity-50"
        >
          <span className="text-lg leading-none">+</span>
          เพิ่มสินค้า
        </button>
      </div>

      {error && <p className="mb-3 rounded-lg bg-red-50 p-3 text-sm text-brand">{error}</p>}

      <div className="mb-3 flex flex-wrap gap-2">
        {services.map((service) => (
          <button
            key={service.id}
            type="button"
            onClick={() => setActiveServiceId(service.id)}
            className={`flex items-center gap-2 rounded-full px-4 py-1.5 text-sm font-semibold transition ${
              activeServiceId === service.id
                ? 'bg-gradient-to-r from-[#be1a1a] to-[#580c0c] text-white shadow-sm'
                : 'bg-gray-100 text-gray-500 hover:bg-gray-200'
            }`}
          >
            {service.name}
            <span
              className={`rounded-full px-1.5 text-xs ${
                activeServiceId === service.id ? 'bg-white/20' : 'bg-white text-gray-500'
              }`}
            >
              {countByService.get(service.id) ?? 0}
            </span>
          </button>
        ))}
      </div>

      <div className="relative mb-3 max-w-xs">
        <svg
          viewBox="0 0 20 20"
          fill="none"
          stroke="currentColor"
          strokeWidth={1.8}
          className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-brand"
        >
          <circle cx="9" cy="9" r="6" />
          <path d="m14 14 3 3" strokeLinecap="round" />
        </svg>
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="ค้นหายี่ห้อหรือรุ่น"
          className="w-full rounded-full border border-gray-200 bg-white py-2 pl-9 pr-4 text-sm outline-none focus:border-brand"
        />
      </div>

      <div className="overflow-x-auto rounded-2xl border border-gray-200 bg-white shadow-sm">
        <table className="w-full min-w-[560px]">
          <thead>
            <tr className="border-b border-gray-100 text-left text-xs text-gray-400">
              <th className="p-3 font-medium">ยี่ห้อ/รุ่น</th>
              <th className="p-3 font-medium">ราคามาตรฐาน</th>
              <th className="p-3 font-medium">สถานะ</th>
              <th className="p-3 font-medium">จัดการ</th>
            </tr>
          </thead>
          <tbody>
            {visible.length === 0 && (
              <tr>
                <td colSpan={4} className="p-6 text-center text-sm text-gray-400">
                  ยังไม่มีสินค้าในบริการนี้
                </td>
              </tr>
            )}
            {visible.map((product) => (
              <tr key={product.id} className="border-b border-gray-100 last:border-0">
                <td className="p-3">
                  <div className="flex items-center gap-3">
                    {product.imageUrl ? (
                      /* eslint-disable-next-line @next/next/no-img-element */
                      <img
                        src={product.imageUrl}
                        alt=""
                        className="h-10 w-10 shrink-0 rounded-lg object-cover"
                      />
                    ) : (
                      <span className="h-10 w-10 shrink-0 rounded-lg bg-gray-200" />
                    )}
                    <span className="min-w-0">
                      <span className="block truncate text-sm font-bold text-gray-800">
                        {product.name}
                      </span>
                      <span className="block truncate text-xs text-gray-400">
                        {product.description ?? product.grade ?? product.brand ?? product.serviceName}
                      </span>
                    </span>
                  </div>
                </td>
                <td className="whitespace-nowrap p-3 text-sm text-gray-700">
                  {formatBaht(product.price)}
                </td>
                <td className="p-3">
                  <span
                    className={`inline-flex items-center gap-1.5 whitespace-nowrap rounded-full px-2.5 py-1 text-xs font-medium ${
                      product.active ? 'bg-emerald-50 text-emerald-700' : 'bg-red-50 text-brand'
                    }`}
                  >
                    <span
                      className={`h-1.5 w-1.5 rounded-full ${
                        product.active ? 'bg-emerald-500' : 'bg-brand'
                      }`}
                    />
                    {product.active ? 'พร้อมจำหน่าย' : 'ไม่พร้อมจำหน่าย'}
                  </span>
                </td>
                <td className="p-3">
                  <div className="flex gap-2">
                    <button
                      type="button"
                      aria-label={`แก้ไข ${product.name}`}
                      onClick={() => {
                        setEditing(product);
                        setFormError(null);
                      }}
                      className="rounded-lg bg-amber-100 p-2 text-amber-700 hover:bg-amber-200"
                    >
                      <PencilIcon />
                    </button>
                    <button
                      type="button"
                      aria-label={`ลบ ${product.name}`}
                      onClick={() => handleDelete(product)}
                      className="rounded-lg bg-red-100 p-2 text-brand hover:bg-red-200"
                    >
                      <TrashIcon />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {(creating || editing) && (
        <ProductFormModal
          mode={editing ? 'edit' : 'create'}
          serviceName={editing ? editing.serviceName : (activeService?.name ?? '')}
          initial={editing ? toFormValues(editing) : EMPTY_PRODUCT_FORM}
          saving={saving}
          error={formError}
          onClose={() => {
            setCreating(false);
            setEditing(null);
          }}
          onSubmit={handleSubmit}
        />
      )}
    </div>
  );
}
