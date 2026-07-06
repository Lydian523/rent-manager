-- ============================================================
-- 出租房屋管理系統 v1.0 — Supabase 資料庫結構
-- 使用方式：Supabase 後台 → SQL Editor → 貼上全部 → Run
-- ============================================================

-- 物件（建築）
create table if not exists buildings (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  note text default '',
  updated_at timestamptz default now()
);

-- 房間
create table if not exists rooms (
  id uuid primary key default gen_random_uuid(),
  building_id uuid references buildings(id),
  room_no text not null,          -- 房號，例如 2F-201
  floor text default '',
  room_type text default '雅房',   -- 店面 / 雅房 / 套房 / 倉庫
  monthly_rent integer default 0,
  water_fee integer default 250,
  gas_fee integer default 250,
  status text default '空房',      -- 出租中 / 空房 / 整修中 / 自用
  note text default '',
  updated_at timestamptz default now()
);

-- 房客
create table if not exists tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text default '',
  emergency_name text default '',
  emergency_phone text default '',
  note text default '',
  updated_at timestamptz default now()
);

-- 租約
create table if not exists leases (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references rooms(id),
  tenant_id uuid references tenants(id),
  start_date date,
  end_date date,
  deposit integer default 0,        -- 押金
  prepaid_months integer default 0, -- 預繳月數
  active boolean default true,
  moveout_reading numeric,          -- 退租結算電錶讀數
  note text default '',
  updated_at timestamptz default now()
);

-- 每月租金紀錄
create table if not exists rent_payments (
  id uuid primary key default gen_random_uuid(),
  lease_id uuid references leases(id),
  room_id uuid references rooms(id),
  period text not null,             -- YYYY-MM
  amount integer default 0,         -- 房租＋水＋瓦斯
  paid boolean default false,
  paid_date date,
  note text default '',
  updated_at timestamptz default now()
);

-- 電錶讀數（結算抄錶 / 期中快抄）
create table if not exists meter_readings (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references rooms(id),
  reading_date date not null,
  value numeric not null,
  kind text default '結算',         -- 結算 / 快抄 / 退租
  photo_url text default '',
  note text default '',
  updated_at timestamptz default now()
);

-- 半年電費結算單
create table if not exists electricity_bills (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references rooms(id),
  period_label text not null,       -- 例如：2026上半年
  start_reading numeric,
  end_reading numeric,
  usage_kwh numeric,
  unit_price numeric default 4,
  amount integer,
  paid boolean default false,
  paid_date date,
  updated_at timestamptz default now()
);

-- 設備／耗材（燈管、熱水器電池等）
create table if not exists fixtures (
  id uuid primary key default gen_random_uuid(),
  building_id uuid references buildings(id),
  location text not null,           -- 例如：2樓樓梯間
  item_type text default '燈管',     -- 燈管 / 熱水器電池 / 其他
  model text default '1尺燈管',
  daily_hours numeric default 24,   -- 每日點亮時數
  rated_hours numeric default 15000,-- 額定壽命（小時），電池類可留 0 改用預期天數
  expected_days integer default 0,  -- 0 = 由 rated_hours/daily_hours 自動計算
  last_replaced date,
  note text default '',
  updated_at timestamptz default now()
);

-- 更換紀錄
create table if not exists replacements (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid references fixtures(id),
  replaced_date date not null,
  note text default '',
  updated_at timestamptz default now()
);

-- 總錶帳單（台水 / 台電 / 瓦斯行）→ 抓漏警示用
create table if not exists utility_bills (
  id uuid primary key default gen_random_uuid(),
  building_id uuid references buildings(id),
  kind text not null,               -- 水 / 電 / 瓦斯
  period_label text not null,       -- 例如：2026-05/06
  amount integer not null,
  usage_amount numeric,             -- 度數（可留空）
  note text default '',
  updated_at timestamptz default now()
);

-- ============================================================
-- RLS：家人共用 anon key，開放全部操作
-- （若日後要更嚴格，可改成 Supabase Auth 登入制）
-- ============================================================
do $$
declare t text;
begin
  foreach t in array array['buildings','rooms','tenants','leases','rent_payments',
                           'meter_readings','electricity_bills','fixtures',
                           'replacements','utility_bills']
  loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists "allow_all_%s" on %I', t, t);
    execute format('create policy "allow_all_%s" on %I for all using (true) with check (true)', t, t);
  end loop;
end $$;

-- ============================================================
-- 抄錶照片儲存空間：
-- 後台 → Storage → New bucket → 名稱 meter-photos → 勾選 Public
-- 再執行以下兩行開放上傳：
-- ============================================================
-- create policy "photo_upload" on storage.objects for insert with check (bucket_id = 'meter-photos');
-- create policy "photo_read"   on storage.objects for select using (bucket_id = 'meter-photos');
