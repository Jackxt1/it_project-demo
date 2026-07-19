-- BKK Carglass and Service - PostgreSQL schema

CREATE TABLE IF NOT EXISTS users (
    id            BIGSERIAL PRIMARY KEY,
    full_name     VARCHAR(150) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    phone         VARCHAR(30),
    password_hash VARCHAR(255) NOT NULL,
    role          VARCHAR(20)  NOT NULL DEFAULT 'CUSTOMER' CHECK (role IN ('CUSTOMER', 'ADMIN')),
    created_at    TIMESTAMP    NOT NULL DEFAULT now(),
    updated_at    TIMESTAMP    NOT NULL DEFAULT now()
)@@

ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(255)@@

CREATE TABLE IF NOT EXISTS services (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(150) NOT NULL,
    description TEXT,
    base_price  NUMERIC(10, 2),
    created_at  TIMESTAMP NOT NULL DEFAULT now(),
    updated_at  TIMESTAMP NOT NULL DEFAULT now()
)@@

CREATE TABLE IF NOT EXISTS products (
    id                BIGSERIAL PRIMARY KEY,
    service_id        BIGINT REFERENCES services (id) ON DELETE SET NULL,
    name              VARCHAR(150) NOT NULL,
    brand             VARCHAR(100),
    grade             VARCHAR(50),
    heat_rejection_pct SMALLINT CHECK (heat_rejection_pct BETWEEN 0 AND 100),
    uv_rejection_pct  SMALLINT CHECK (uv_rejection_pct BETWEEN 0 AND 100),
    vlt_pct           SMALLINT CHECK (vlt_pct BETWEEN 0 AND 100),
    price             NUMERIC(10, 2) NOT NULL,
    description       TEXT,
    image_url         VARCHAR(500),
    created_at        TIMESTAMP NOT NULL DEFAULT now(),
    updated_at        TIMESTAMP NOT NULL DEFAULT now()
)@@

ALTER TABLE products ADD COLUMN IF NOT EXISTS grade VARCHAR(50)@@
ALTER TABLE products ADD COLUMN IF NOT EXISTS heat_rejection_pct SMALLINT@@
ALTER TABLE products ADD COLUMN IF NOT EXISTS uv_rejection_pct SMALLINT@@
ALTER TABLE products ADD COLUMN IF NOT EXISTS vlt_pct SMALLINT@@

ALTER TABLE services ADD COLUMN IF NOT EXISTS max_per_slot INTEGER NOT NULL DEFAULT 2@@

ALTER TABLE products ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true@@

CREATE TABLE IF NOT EXISTS vehicles (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    vehicle_type  VARCHAR(20) NOT NULL CHECK (vehicle_type IN ('SEDAN', 'PICKUP', 'SUV', 'OTHER')),
    brand_model   VARCHAR(150) NOT NULL,
    year          SMALLINT,
    license_plate VARCHAR(30) NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT now(),
    updated_at    TIMESTAMP NOT NULL DEFAULT now()
)@@

CREATE INDEX IF NOT EXISTS idx_vehicles_user_id ON vehicles (user_id)@@

CREATE TABLE IF NOT EXISTS technicians (
    id         BIGSERIAL PRIMARY KEY,
    full_name  VARCHAR(150) NOT NULL,
    phone      VARCHAR(30),
    is_active  BOOLEAN   NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
)@@

CREATE TABLE IF NOT EXISTS bookings (
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    service_id   BIGINT NOT NULL REFERENCES services (id) ON DELETE RESTRICT,
    product_id   BIGINT REFERENCES products (id) ON DELETE SET NULL,
    booking_date DATE NOT NULL,
    time_slot    VARCHAR(20) NOT NULL,
    status       VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                 CHECK (status IN ('PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
    budget       NUMERIC(10, 2),
    image_url    VARCHAR(500),
    quote_price  NUMERIC(10, 2),
    notes        TEXT,
    created_at   TIMESTAMP NOT NULL DEFAULT now(),
    updated_at   TIMESTAMP NOT NULL DEFAULT now()
)@@

ALTER TABLE bookings ADD COLUMN IF NOT EXISTS technician_id BIGINT
    REFERENCES technicians (id) ON DELETE SET NULL@@
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS vehicle_id BIGINT
    REFERENCES vehicles (id) ON DELETE SET NULL@@
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS install_area VARCHAR(20)
    CHECK (install_area IS NULL OR install_area IN ('FULL', 'FRONT_BACK', 'FRONT', 'BACK'))@@
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS order_code VARCHAR(30) UNIQUE@@
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS payment_type VARCHAR(20)
    CHECK (payment_type IS NULL OR payment_type IN ('DEPOSIT', 'FULL'))@@
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS paid_amount NUMERIC(10, 2) NOT NULL DEFAULT 0@@
CREATE INDEX IF NOT EXISTS idx_bookings_vehicle_id ON bookings (vehicle_id)@@

CREATE TABLE IF NOT EXISTS booking_status_history (
    id         BIGSERIAL PRIMARY KEY,
    booking_id BIGINT NOT NULL REFERENCES bookings (id) ON DELETE CASCADE,
    status     VARCHAR(20) NOT NULL,
    note       TEXT,
    changed_by BIGINT REFERENCES users (id) ON DELETE SET NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT now()
)@@

CREATE TABLE IF NOT EXISTS reviews (
    id         BIGSERIAL PRIMARY KEY,
    booking_id BIGINT NOT NULL UNIQUE REFERENCES bookings (id) ON DELETE CASCADE,
    user_id    BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    rating     SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment    TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT now()
)@@

CREATE TABLE IF NOT EXISTS chat_messages (
    id          BIGSERIAL PRIMARY KEY,
    booking_id  BIGINT NOT NULL REFERENCES bookings (id) ON DELETE CASCADE,
    sender_type VARCHAR(20) NOT NULL CHECK (sender_type IN ('CUSTOMER', 'ADMIN', 'BOT')),
    sender_id   BIGINT REFERENCES users (id) ON DELETE SET NULL,
    message     TEXT NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT now(),
    read_at     TIMESTAMP
)@@

CREATE INDEX IF NOT EXISTS idx_chat_messages_booking_id ON chat_messages (booking_id)@@

CREATE TABLE IF NOT EXISTS notifications (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    title      VARCHAR(200) NOT NULL,
    body       TEXT NOT NULL,
    type       VARCHAR(30) NOT NULL DEFAULT 'OTHER'
               CHECK (type IN ('BOOKING_STATUS', 'QUOTE', 'JOB_ASSIGNED', 'CHAT', 'OTHER')),
    booking_id BIGINT REFERENCES bookings (id) ON DELETE SET NULL,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    read_at    TIMESTAMP
)@@

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications (user_id)@@

CREATE INDEX IF NOT EXISTS idx_products_service_id ON products (service_id)@@
CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON bookings (user_id)@@
CREATE INDEX IF NOT EXISTS idx_bookings_service_id ON bookings (service_id)@@
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings (status)@@
CREATE INDEX IF NOT EXISTS idx_bookings_technician_id ON bookings (technician_id)@@
CREATE INDEX IF NOT EXISTS idx_booking_status_history_booking_id ON booking_status_history (booking_id)@@
CREATE INDEX IF NOT EXISTS idx_reviews_user_id ON reviews (user_id)@@

-- keep updated_at fresh on row updates
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql@@

DROP TRIGGER IF EXISTS trg_users_updated_at ON users@@
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at()@@

DROP TRIGGER IF EXISTS trg_services_updated_at ON services@@
CREATE TRIGGER trg_services_updated_at BEFORE UPDATE ON services
    FOR EACH ROW EXECUTE FUNCTION set_updated_at()@@

DROP TRIGGER IF EXISTS trg_products_updated_at ON products@@
CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION set_updated_at()@@

DROP TRIGGER IF EXISTS trg_bookings_updated_at ON bookings@@
CREATE TRIGGER trg_bookings_updated_at BEFORE UPDATE ON bookings
    FOR EACH ROW EXECUTE FUNCTION set_updated_at()@@

DROP TRIGGER IF EXISTS trg_technicians_updated_at ON technicians@@
CREATE TRIGGER trg_technicians_updated_at BEFORE UPDATE ON technicians
    FOR EACH ROW EXECUTE FUNCTION set_updated_at()@@

DROP TRIGGER IF EXISTS trg_vehicles_updated_at ON vehicles@@
CREATE TRIGGER trg_vehicles_updated_at BEFORE UPDATE ON vehicles
    FOR EACH ROW EXECUTE FUNCTION set_updated_at()@@

-- Seed: car wash service and packages (idempotent)
INSERT INTO services (name, description, base_price, max_per_slot)
SELECT 'ล้างรถ', 'บริการล้างทำความสะอาดรถยนต์ที่ร้าน', 0, 5
WHERE NOT EXISTS (SELECT 1 FROM services WHERE name = 'ล้างรถ')@@

INSERT INTO products (service_id, name, price, description)
SELECT s.id, 'ล้างธรรมดา', 200, 'ล้างภายนอก เช็ดแห้ง ดูดฝุ่นภายใน'
FROM services s
WHERE s.name = 'ล้างรถ'
  AND NOT EXISTS (SELECT 1 FROM products WHERE name = 'ล้างธรรมดา')@@

INSERT INTO products (service_id, name, price, description)
SELECT s.id, 'ล้างพรีเมียม', 500, 'ล้างภายนอก เคลือบเงาสี ดูดฝุ่น เช็ดคอนโซลภายใน'
FROM services s
WHERE s.name = 'ล้างรถ'
  AND NOT EXISTS (SELECT 1 FROM products WHERE name = 'ล้างพรีเมียม')@@

INSERT INTO products (service_id, name, price, description)
SELECT s.id, 'ล้าง + ขัดเคลือบสีเต็มระบบ', 1500, 'ล้างละเอียด ขัดลบรอยขนแมว เคลือบสีเต็มระบบ'
FROM services s
WHERE s.name = 'ล้างรถ'
  AND NOT EXISTS (SELECT 1 FROM products WHERE name = 'ล้าง + ขัดเคลือบสีเต็มระบบ')@@

-- Phase 3: OWNER/TECHNICIAN roles, technician login link
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check@@
ALTER TABLE users ADD CONSTRAINT users_role_check
    CHECK (role IN ('CUSTOMER', 'ADMIN', 'OWNER', 'TECHNICIAN'))@@

ALTER TABLE technicians ADD COLUMN IF NOT EXISTS user_id BIGINT UNIQUE REFERENCES users (id)@@@@