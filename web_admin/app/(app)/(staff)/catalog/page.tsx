import ServiceManager from './ServiceManager';
import ProductManager from './ProductManager';

export default function CatalogPage() {
  return (
    <div className="space-y-8">
      <div>
        <h1 className="mb-4 text-xl font-bold text-brand-deep">บริการ</h1>
        <ServiceManager />
      </div>
      <div>
        <h2 className="mb-4 text-xl font-bold text-brand-deep">สินค้า (ฟิล์ม)</h2>
        <ProductManager />
      </div>
    </div>
  );
}
