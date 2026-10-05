'use client';
import { useState } from 'react';
import ProductManager from './ProductManager';
import ServiceManager from './ServiceManager';

/**
 * The products table is the page, as in the design. Service settings — base
 * price and the per-slot queue cap — have no place in that design but are
 * only set here, so they sit behind a link instead of a second table.
 */
export default function CatalogView() {
  const [showServices, setShowServices] = useState(false);

  return (
    <div>
      <ProductManager />

      <div className="mt-6">
        <button
          type="button"
          onClick={() => setShowServices((v) => !v)}
          className="text-sm font-semibold text-brand underline"
        >
          {showServices ? 'ซ่อนการตั้งค่าบริการ' : 'ตั้งค่าบริการและคิวต่อช่วงเวลา'}
        </button>

        {showServices && (
          <div className="mt-3">
            <ServiceManager />
          </div>
        )}
      </div>
    </div>
  );
}
