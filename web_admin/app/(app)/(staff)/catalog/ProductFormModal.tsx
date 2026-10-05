'use client';
import { useState, type FormEvent } from 'react';
import Image from 'next/image';
import type { Product } from '@/lib/types';

export interface ProductFormValues {
  name: string;
  description: string;
  price: string;
  active: boolean;
  brand: string;
  grade: string;
  heatRejectionPct: string;
  uvRejectionPct: string;
  vltPct: string;
  imageUrl: string;
}

export const EMPTY_PRODUCT_FORM: ProductFormValues = {
  name: '',
  description: '',
  price: '',
  active: true,
  brand: '',
  grade: '',
  heatRejectionPct: '',
  uvRejectionPct: '',
  vltPct: '',
  imageUrl: '',
};

export function toFormValues(product: Product): ProductFormValues {
  return {
    name: product.name,
    description: product.description ?? '',
    price: String(product.price),
    active: product.active,
    brand: product.brand ?? '',
    grade: product.grade ?? '',
    heatRejectionPct: product.heatRejectionPct === null ? '' : String(product.heatRejectionPct),
    uvRejectionPct: product.uvRejectionPct === null ? '' : String(product.uvRejectionPct),
    vltPct: product.vltPct === null ? '' : String(product.vltPct),
    imageUrl: product.imageUrl ?? '',
  };
}

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <label className="block">
      <span className="mb-1 block text-sm text-gray-600">{label}</span>
      {children}
    </label>
  );
}

const inputClass =
  'w-full rounded-lg border border-gray-200 bg-gray-50 px-3 py-2 text-sm outline-none focus:border-brand';

export default function ProductFormModal({
  mode,
  serviceName,
  initial,
  saving,
  error,
  onClose,
  onSubmit,
}: {
  mode: 'create' | 'edit';
  serviceName: string;
  initial: ProductFormValues;
  saving: boolean;
  error: string | null;
  onClose: () => void;
  onSubmit: (values: ProductFormValues) => void;
}) {
  const [values, setValues] = useState<ProductFormValues>(initial);
  // The shop's film specs drive the chatbot's recommendations, so they stay
  // editable — tucked behind a toggle to keep the common case as short as
  // the mockup's form.
  const [showSpecs, setShowSpecs] = useState(false);

  function set<K extends keyof ProductFormValues>(key: K, value: ProductFormValues[K]) {
    setValues((prev) => ({ ...prev, [key]: value }));
  }

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    onSubmit(values);
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <form
        onSubmit={handleSubmit}
        className="relative max-h-full w-full max-w-sm overflow-y-auto rounded-2xl bg-white p-6 shadow-xl"
      >
        <button
          type="button"
          onClick={onClose}
          aria-label="ปิด"
          className="absolute right-3 top-3 flex h-7 w-7 items-center justify-center rounded-full bg-brand text-white"
        >
          <svg viewBox="0 0 20 20" fill="currentColor" className="h-4 w-4">
            <path d="M6.3 6.3a1 1 0 0 1 1.4 0L10 8.6l2.3-2.3a1 1 0 1 1 1.4 1.4L11.4 10l2.3 2.3a1 1 0 0 1-1.4 1.4L10 11.4l-2.3 2.3a1 1 0 0 1-1.4-1.4L8.6 10 6.3 7.7a1 1 0 0 1 0-1.4Z" />
          </svg>
        </button>

        <Image
          src="/logo-red-mark.png"
          alt="BKK Car Glass and Service"
          width={160}
          height={44}
          className="mx-auto h-11 w-auto object-contain"
        />
        <h2 className="mt-3 text-center text-lg font-bold text-brand-deep">
          {mode === 'create' ? 'เพิ่มสินค้า' : 'แก้ไขสินค้า'}
        </h2>
        <p className="mb-4 text-center text-xs text-gray-400">{serviceName}</p>

        {error && <p className="mb-3 rounded-lg bg-red-50 p-2 text-sm text-brand">{error}</p>}

        <div className="space-y-3">
          <Field label="ชื่อ/รุ่น">
            <input
              value={values.name}
              onChange={(e) => set('name', e.target.value)}
              required
              className={inputClass}
            />
          </Field>

          <Field label="รายละเอียดเพิ่มเติม">
            <input
              value={values.description}
              onChange={(e) => set('description', e.target.value)}
              className={inputClass}
            />
          </Field>

          <Field label="ราคามาตรฐาน">
            <input
              type="number"
              min={0}
              value={values.price}
              onChange={(e) => set('price', e.target.value)}
              required
              className={inputClass}
            />
          </Field>

          {mode === 'edit' && (
            <fieldset>
              <legend className="mb-1 text-sm text-gray-600">สถานะ</legend>
              <div className="space-y-1.5">
                {[
                  { value: true, label: 'พร้อมจำหน่าย' },
                  { value: false, label: 'ไม่พร้อมจำหน่าย' },
                ].map((option) => (
                  <label key={String(option.value)} className="flex items-center gap-2 text-sm">
                    <input
                      type="radio"
                      name="active"
                      checked={values.active === option.value}
                      onChange={() => set('active', option.value)}
                      className="accent-brand"
                    />
                    {option.label}
                  </label>
                ))}
              </div>
            </fieldset>
          )}

          <button
            type="button"
            onClick={() => setShowSpecs((v) => !v)}
            className="text-xs font-semibold text-brand underline"
          >
            {showSpecs ? 'ซ่อนสเปคฟิล์ม' : 'สเปคฟิล์มและรูปภาพ'}
          </button>

          {showSpecs && (
            <div className="space-y-3 rounded-xl bg-gray-50 p-3">
              <Field label="ยี่ห้อ">
                <input
                  value={values.brand}
                  onChange={(e) => set('brand', e.target.value)}
                  className={inputClass}
                />
              </Field>
              <Field label="เกรด">
                <input
                  value={values.grade}
                  onChange={(e) => set('grade', e.target.value)}
                  className={inputClass}
                />
              </Field>
              <div className="grid grid-cols-3 gap-2">
                <Field label="กันร้อน %">
                  <input
                    type="number"
                    value={values.heatRejectionPct}
                    onChange={(e) => set('heatRejectionPct', e.target.value)}
                    className={inputClass}
                  />
                </Field>
                <Field label="กันยูวี %">
                  <input
                    type="number"
                    value={values.uvRejectionPct}
                    onChange={(e) => set('uvRejectionPct', e.target.value)}
                    className={inputClass}
                  />
                </Field>
                <Field label="ความเข้ม %">
                  <input
                    type="number"
                    value={values.vltPct}
                    onChange={(e) => set('vltPct', e.target.value)}
                    className={inputClass}
                  />
                </Field>
              </div>
              <Field label="ลิงก์รูปภาพ">
                <input
                  value={values.imageUrl}
                  onChange={(e) => set('imageUrl', e.target.value)}
                  className={inputClass}
                />
              </Field>
            </div>
          )}
        </div>

        <button
          type="submit"
          disabled={saving}
          className="mt-5 w-full rounded-lg bg-brand-dark py-2.5 text-sm font-bold text-white hover:bg-brand disabled:opacity-50"
        >
          {saving ? 'กำลังบันทึก…' : 'ยืนยัน'}
        </button>
      </form>
    </div>
  );
}
