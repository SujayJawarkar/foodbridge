-- =============================================================================
-- FoodBridge | Flyway Migration V1__init_schema.sql
-- Author      : Vidyasagar (DB & AI Lead)
-- Description : Initial schema — all 11 core entities, enums, indexes, constraints
-- DB          : PostgreSQL 15 (Supabase)
-- Extensions  : uuid-ossp, postgis
-- IMPORTANT   : This file is IMMUTABLE once merged to dev.
--               Any schema change must be a new V2__ migration.
-- =============================================================================


-- =============================================================================
-- EXTENSIONS
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;


-- =============================================================================
-- ENUM TYPES
-- =============================================================================

-- Role a user holds on the platform
CREATE TYPE user_role AS ENUM (
    'CUSTOMER',
    'RESTAURANT_OWNER',
    'HOME_CHEF',
    'RIDER',
    'NGO_PARTNER',
    'SUPER_ADMIN'
);

-- Full order lifecycle (Section 3.4.2 of SRS)
CREATE TYPE order_status AS ENUM (
    'PLACED',
    'ACCEPTED',
    'PREPARING',
    'READY_FOR_PICKUP',
    'PICKED_UP',
    'OUT_FOR_DELIVERY',
    'DELIVERED',
    'CANCELLED'
);

-- Whether an order is home delivery or customer self-pickup
CREATE TYPE order_type AS ENUM (
    'DELIVERY',
    'TAKEAWAY'
);

-- Discriminator: menu item or order belongs to a restaurant or a home chef
CREATE TYPE source_type AS ENUM (
    'RESTAURANT',
    'HOME_CHEF'
);

-- Discriminator: a review targets a restaurant, home chef, or rider
CREATE TYPE target_type AS ENUM (
    'RESTAURANT',
    'HOME_CHEF',
    'RIDER'
);

-- Payment method chosen at checkout
CREATE TYPE payment_method AS ENUM (
    'UPI',
    'COD'
);

-- Lifecycle of a donation listing
CREATE TYPE donation_status AS ENUM (
    'OPEN',
    'ACCEPTED',
    'COMPLETED',
    'CANCELLED'
);


-- =============================================================================
-- TABLE: users
-- Central identity table. Every actor on the platform has a row here.
-- dietary_prefs  : e.g. {"vegan": true, "jain": false, "gluten_free": false}
-- allergy_flags  : e.g. {"nuts": true, "dairy": false}
-- =============================================================================

CREATE TABLE users (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    phone           VARCHAR(15)     NOT NULL,
    email           VARCHAR(255),
    name            VARCHAR(255)    NOT NULL,
    role            user_role       NOT NULL DEFAULT 'CUSTOMER',
    dietary_prefs   JSONB           NOT NULL DEFAULT '{}',
    allergy_flags   JSONB           NOT NULL DEFAULT '{}',
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT users_phone_unique   UNIQUE (phone),
    CONSTRAINT users_email_unique   UNIQUE (email),
    CONSTRAINT users_phone_format   CHECK (phone ~ '^\+?[0-9]{10,15}$')
);

COMMENT ON TABLE  users                IS 'Central identity for all platform actors';
COMMENT ON COLUMN users.dietary_prefs IS 'JSONB map of dietary flags e.g. {"vegan":true}';
COMMENT ON COLUMN users.allergy_flags IS 'JSONB map of allergy flags e.g. {"nuts":true}';


-- =============================================================================
-- TABLE: restaurants
-- Registered restaurant listings. owner_id links to a user with RESTAURANT_OWNER role.
-- location       : PostGIS point (longitude, latitude) EPSG:4326
-- cuisine_tags   : e.g. ["punjabi", "north_indian", "street_food"]
-- operating_hours: e.g. {"mon":{"open":"09:00","close":"22:00"}, ...}
-- =============================================================================

CREATE TABLE restaurants (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id        UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    name            VARCHAR(255)    NOT NULL,
    fssai_no        VARCHAR(50)     NOT NULL,
    address         TEXT            NOT NULL,
    location        GEOGRAPHY(POINT, 4326),
    cuisine_tags    JSONB           NOT NULL DEFAULT '[]',
    operating_hours JSONB           NOT NULL DEFAULT '{}',
    rating          NUMERIC(3, 2)   NOT NULL DEFAULT 0.00,
    is_active       BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT restaurants_fssai_unique     UNIQUE (fssai_no),
    CONSTRAINT restaurants_rating_range     CHECK (rating >= 0 AND rating <= 5)
);

COMMENT ON TABLE  restaurants          IS 'Restaurant listings pending or approved by admin';
COMMENT ON COLUMN restaurants.location IS 'PostGIS GEOGRAPHY point — longitude first, latitude second';


-- =============================================================================
-- TABLE: home_chefs
-- Individual home cooks. user_id links to the users table (HOME_CHEF role).
-- operating_hours: same shape as restaurants
-- =============================================================================

CREATE TABLE home_chefs (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    bio                 TEXT,
    cuisine_speciality  VARCHAR(255),
    operating_hours     JSONB           NOT NULL DEFAULT '{}',
    rating              NUMERIC(3, 2)   NOT NULL DEFAULT 0.00,
    is_active           BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT home_chefs_user_unique   UNIQUE (user_id),
    CONSTRAINT home_chefs_rating_range  CHECK (rating >= 0 AND rating <= 5)
);

COMMENT ON TABLE home_chefs IS 'Home chef profiles linked one-to-one with a users row';


-- =============================================================================
-- TABLE: menu_items
-- Items listed by either a restaurant or a home chef.
-- source_id + source_type form a polymorphic FK (no hard FK — enforced in app layer).
-- nutrition : e.g. {"calories":350,"protein_g":22,"carbs_g":40,"fat_g":10}
-- =============================================================================

CREATE TABLE menu_items (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id       UUID            NOT NULL,
    source_type     source_type     NOT NULL,
    name            VARCHAR(255)    NOT NULL,
    description     TEXT,
    price           NUMERIC(10, 2)  NOT NULL,
    category        VARCHAR(100),
    nutrition       JSONB           NOT NULL DEFAULT '{}',
    dietary_tags    JSONB           NOT NULL DEFAULT '[]',
    is_available    BOOLEAN         NOT NULL DEFAULT TRUE,
    image_url       TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT menu_items_price_positive    CHECK (price > 0)
);

COMMENT ON TABLE  menu_items             IS 'Menu items for restaurants and home chefs (polymorphic source)';
COMMENT ON COLUMN menu_items.source_id   IS 'FK to restaurants.id or home_chefs.id depending on source_type';
COMMENT ON COLUMN menu_items.nutrition   IS 'Nutritional info: calories, protein_g, carbs_g, fat_g per serving';
COMMENT ON COLUMN menu_items.dietary_tags IS 'e.g. ["vegan","gluten_free"]';


-- =============================================================================
-- TABLE: ngos
-- Registered NGO partners. contact_user_id links to the users table (NGO_PARTNER role).
-- =============================================================================

CREATE TABLE ngos (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    org_name            VARCHAR(255)    NOT NULL,
    reg_number          VARCHAR(100)    NOT NULL,
    contact_user_id     UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    service_area        GEOGRAPHY(POINT, 4326),
    service_radius_km   NUMERIC(6, 2)   NOT NULL DEFAULT 10.00,
    is_verified         BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT ngos_reg_number_unique   UNIQUE (reg_number),
    CONSTRAINT ngos_radius_positive     CHECK (service_radius_km > 0)
);

COMMENT ON TABLE ngos IS 'NGO partners that receive food donation listings';


-- =============================================================================
-- TABLE: riders
-- Delivery riders. user_id links to a user with RIDER role.
-- current_location updates frequently via Supabase Realtime (live tracking).
-- =============================================================================

CREATE TABLE riders (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    vehicle_type        VARCHAR(50)     NOT NULL,
    licence_no          VARCHAR(50)     NOT NULL,
    aadhaar_no          VARCHAR(12),
    is_active           BOOLEAN         NOT NULL DEFAULT FALSE,
    is_available        BOOLEAN         NOT NULL DEFAULT FALSE,
    current_location    GEOGRAPHY(POINT, 4326),
    rating              NUMERIC(3, 2)   NOT NULL DEFAULT 0.00,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT riders_user_unique       UNIQUE (user_id),
    CONSTRAINT riders_licence_unique    UNIQUE (licence_no),
    CONSTRAINT riders_rating_range      CHECK (rating >= 0 AND rating <= 5),
    CONSTRAINT riders_aadhaar_format    CHECK (aadhaar_no IS NULL OR aadhaar_no ~ '^[0-9]{12}$')
);

COMMENT ON TABLE  riders                  IS 'Delivery riders; current_location drives Realtime live tracking';
COMMENT ON COLUMN riders.current_location IS 'Updated every 5s by rider app; published via Supabase Realtime';


-- =============================================================================
-- TABLE: orders
-- One row per customer order.
-- items JSONB stores the snapshot of ordered items at time of purchase:
--   [{"menu_item_id":"...","name":"...","qty":2,"unit_price":120.00,"instructions":"..."}]
-- =============================================================================

CREATE TABLE orders (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id     UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    source_id       UUID            NOT NULL,
    source_type     source_type     NOT NULL,
    rider_id        UUID            REFERENCES riders(id) ON DELETE SET NULL,
    order_type      order_type      NOT NULL DEFAULT 'DELIVERY',
    status          order_status    NOT NULL DEFAULT 'PLACED',
    items           JSONB           NOT NULL DEFAULT '[]',
    total_amount    NUMERIC(10, 2)  NOT NULL,
    delivery_fee    NUMERIC(8, 2)   NOT NULL DEFAULT 0.00,
    platform_fee    NUMERIC(8, 2)   NOT NULL DEFAULT 0.00,
    payment_method  payment_method  NOT NULL,
    delivery_address JSONB,
    pickup_otp      VARCHAR(6),
    scheduled_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT orders_total_positive        CHECK (total_amount > 0),
    CONSTRAINT orders_delivery_fee_nn       CHECK (delivery_fee >= 0),
    CONSTRAINT orders_platform_fee_nn       CHECK (platform_fee >= 0),
    CONSTRAINT orders_takeaway_no_rider     CHECK (
        order_type = 'DELIVERY' OR rider_id IS NULL
    ),
    CONSTRAINT orders_scheduled_future      CHECK (
        scheduled_at IS NULL OR scheduled_at > created_at
    )
);

COMMENT ON TABLE  orders               IS 'Customer orders; items is a point-in-time JSONB snapshot';
COMMENT ON COLUMN orders.items         IS '[{menu_item_id, name, qty, unit_price, instructions}]';
COMMENT ON COLUMN orders.pickup_otp    IS 'For TAKEAWAY orders: customer shows this OTP to restaurant staff';
COMMENT ON COLUMN orders.delivery_address IS '{line1, line2, city, lat, lng} snapshot at order time';


-- =============================================================================
-- TABLE: donations
-- Surplus food donation listings created by function hosts.
-- pickup_location: PostGIS point of where NGO must collect the food.
-- pickup_window  : e.g. {"start":"2024-04-14T18:00:00+05:30","end":"2024-04-14T20:00:00+05:30"}
-- =============================================================================

CREATE TABLE donations (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    host_user_id        UUID            NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    ngo_id              UUID            REFERENCES ngos(id) ON DELETE SET NULL,
    rider_id            UUID            REFERENCES riders(id) ON DELETE SET NULL,
    food_description    TEXT            NOT NULL,
    quantity_estimate   VARCHAR(255)    NOT NULL,
    pickup_location     GEOGRAPHY(POINT, 4326) NOT NULL,
    pickup_window       JSONB           NOT NULL,
    status              donation_status NOT NULL DEFAULT 'OPEN',
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT now()
);

COMMENT ON TABLE  donations                IS 'Surplus food donation listings for NGO pickup';
COMMENT ON COLUMN donations.pickup_window  IS '{"start":"ISO8601","end":"ISO8601"} pickup availability window';


-- =============================================================================
-- TABLE: recipes
-- Curated recipe database for the Cook at Home section.
-- ingredients   : [{"name":"Paneer","qty":"200g"},{"name":"Tomato","qty":"3"}]
-- instructions  : [{"step":1,"text":"..."},{"step":2,"text":"..."}]
-- =============================================================================

CREATE TABLE recipes (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    title           VARCHAR(255)    NOT NULL,
    cuisine         VARCHAR(100),
    dietary_tags    JSONB           NOT NULL DEFAULT '[]',
    prep_time_mins  INTEGER         NOT NULL,
    difficulty      VARCHAR(50),
    ingredients     JSONB           NOT NULL DEFAULT '[]',
    instructions    JSONB           NOT NULL DEFAULT '[]',
    youtube_url     TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT recipes_prep_time_positive   CHECK (prep_time_mins > 0),
    CONSTRAINT recipes_difficulty_valid     CHECK (
        difficulty IS NULL OR difficulty IN ('EASY', 'MEDIUM', 'HARD')
    )
);

COMMENT ON TABLE  recipes              IS 'Curated recipe database; YouTube embed URL may be null (fallback state required)';
COMMENT ON COLUMN recipes.ingredients  IS '[{name, qty}] — customer can scale for serving count';
COMMENT ON COLUMN recipes.instructions IS '[{step, text}] — ordered step-by-step instructions';


-- =============================================================================
-- TABLE: nutrition_logs
-- Auto-logged when a customer places an order (triggered by backend on PLACED status).
-- One row per order; macros copied from menu_items.nutrition at log time.
-- =============================================================================

CREATE TABLE nutrition_logs (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id    UUID            NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    date        DATE            NOT NULL,
    calories    NUMERIC(8, 2)   NOT NULL DEFAULT 0,
    protein_g   NUMERIC(8, 2)   NOT NULL DEFAULT 0,
    carbs_g     NUMERIC(8, 2)   NOT NULL DEFAULT 0,
    fat_g       NUMERIC(8, 2)   NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT nutrition_logs_order_unique  UNIQUE (order_id),
    CONSTRAINT nutrition_logs_cals_nn       CHECK (calories >= 0),
    CONSTRAINT nutrition_logs_protein_nn    CHECK (protein_g >= 0),
    CONSTRAINT nutrition_logs_carbs_nn      CHECK (carbs_g >= 0),
    CONSTRAINT nutrition_logs_fat_nn        CHECK (fat_g >= 0)
);

COMMENT ON TABLE  nutrition_logs         IS 'Per-order nutrition snapshot; private — RLS enforces user-only access';
COMMENT ON COLUMN nutrition_logs.date    IS 'Calendar date in IST (UTC+5:30) at time of order';
COMMENT ON COLUMN nutrition_logs.order_id IS 'Unique — one nutrition log row per order';


-- =============================================================================
-- TABLE: reviews
-- Customer reviews after a DELIVERED order.
-- target_id + target_type: polymorphic — restaurant, home_chef, or rider.
-- =============================================================================

CREATE TABLE reviews (
    id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id    UUID            NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    customer_id UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_id   UUID            NOT NULL,
    target_type target_type     NOT NULL,
    rating      SMALLINT        NOT NULL,
    comment     TEXT,
    photo_url   TEXT,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT now(),

    CONSTRAINT reviews_rating_range         CHECK (rating >= 1 AND rating <= 5),
    CONSTRAINT reviews_order_target_unique  UNIQUE (order_id, target_id, target_type)
);

COMMENT ON TABLE  reviews             IS 'Post-delivery reviews; one review per order per target (food + rider rated separately)';
COMMENT ON COLUMN reviews.target_id   IS 'FK to restaurants.id, home_chefs.id, or riders.id based on target_type';


-- =============================================================================
-- INDEXES
-- Strategy: geo indexes (GIST) for PostGIS; B-tree for FK cols, status,
--           and high-cardinality filter columns used in JPA queries.
-- =============================================================================

-- ---- users ----
CREATE INDEX idx_users_phone    ON users (phone);
CREATE INDEX idx_users_role     ON users (role);

-- ---- restaurants ----
CREATE INDEX idx_restaurants_owner      ON restaurants (owner_id);
CREATE INDEX idx_restaurants_location   ON restaurants USING GIST (location);
CREATE INDEX idx_restaurants_is_active  ON restaurants (is_active);
-- GIN index for cuisine_tags JSONB array containment queries (@>)
CREATE INDEX idx_restaurants_cuisine    ON restaurants USING GIN (cuisine_tags);

-- ---- home_chefs ----
CREATE INDEX idx_home_chefs_user        ON home_chefs (user_id);
CREATE INDEX idx_home_chefs_is_active   ON home_chefs (is_active);

-- ---- menu_items ----
CREATE INDEX idx_menu_items_source          ON menu_items (source_id, source_type);
CREATE INDEX idx_menu_items_is_available    ON menu_items (is_available);
CREATE INDEX idx_menu_items_category        ON menu_items (category);
CREATE INDEX idx_menu_items_dietary_tags    ON menu_items USING GIN (dietary_tags);

-- ---- orders ----
CREATE INDEX idx_orders_customer        ON orders (customer_id);
CREATE INDEX idx_orders_source          ON orders (source_id, source_type);
CREATE INDEX idx_orders_rider           ON orders (rider_id);
CREATE INDEX idx_orders_status          ON orders (status);
CREATE INDEX idx_orders_created_at      ON orders (created_at DESC);
-- Composite: admin analytics — daily revenue query
CREATE INDEX idx_orders_created_status  ON orders (created_at DESC, status);
-- Partial: active orders only (used by rider assignment and live tracking)
CREATE INDEX idx_orders_active          ON orders (rider_id, status)
    WHERE status NOT IN ('DELIVERED', 'CANCELLED');

-- ---- riders ----
CREATE INDEX idx_riders_user            ON riders (user_id);
CREATE INDEX idx_riders_location        ON riders USING GIST (current_location);
CREATE INDEX idx_riders_available       ON riders (is_available, is_active);

-- ---- donations ----
CREATE INDEX idx_donations_host         ON donations (host_user_id);
CREATE INDEX idx_donations_ngo          ON donations (ngo_id);
CREATE INDEX idx_donations_status       ON donations (status);
CREATE INDEX idx_donations_location     ON donations USING GIST (pickup_location);

-- ---- ngos ----
CREATE INDEX idx_ngos_service_area      ON ngos USING GIST (service_area);
CREATE INDEX idx_ngos_is_verified       ON ngos (is_verified);

-- ---- nutrition_logs ----
CREATE INDEX idx_nutrition_logs_user        ON nutrition_logs (user_id);
CREATE INDEX idx_nutrition_logs_user_date   ON nutrition_logs (user_id, date DESC);
-- Composite: 7-day macro trend query
CREATE INDEX idx_nutrition_logs_user_7day   ON nutrition_logs (user_id, date DESC)
    WHERE date >= (CURRENT_DATE - INTERVAL '7 days');

-- ---- reviews ----
CREATE INDEX idx_reviews_order          ON reviews (order_id);
CREATE INDEX idx_reviews_customer       ON reviews (customer_id);
CREATE INDEX idx_reviews_target         ON reviews (target_id, target_type);


-- =============================================================================
-- END OF V1__init_schema.sql
-- Next migration: V2__indexes_realtime.sql
-- =============================================================================