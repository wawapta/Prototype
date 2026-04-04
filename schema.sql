-- ================================================
-- WaWa アプリ 追加テーブル定義
-- Supabase の SQL Editor で実行してください
-- ================================================

-- 1. QRコード管理テーブル
CREATE TABLE IF NOT EXISTS public.qr_codes (
  id          uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  title       text        NOT NULL,
  date_text   text,
  pt_reward   integer     NOT NULL DEFAULT 3,
  expires_at  date,
  scan_count  integer     NOT NULL DEFAULT 0,
  is_active   boolean     NOT NULL DEFAULT true,
  created_at  timestamptz DEFAULT now()
);

-- 2. ノベルティ設定テーブル（id=1 の 1行で管理）
CREATE TABLE IF NOT EXISTS public.novelties (
  id            integer PRIMARY KEY,
  name          text    NOT NULL DEFAULT 'オリジナルトートバッグ',
  description   text    DEFAULT 'WaWaオリジナルデザインのエコバッグです',
  stock         integer NOT NULL DEFAULT 30,
  expire_months integer NOT NULL DEFAULT 3,
  updated_at    timestamptz DEFAULT now()
);
INSERT INTO public.novelties (id, name, description, stock, expire_months)
VALUES (1, 'オリジナルトートバッグ', 'WaWaオリジナルデザインのエコバッグです', 30, 3)
ON CONFLICT (id) DO NOTHING;

-- 3. カレンダーイベントテーブル（お知らせ・行事）
CREATE TABLE IF NOT EXISTS public.calendar_events (
  id          uuid  DEFAULT gen_random_uuid() PRIMARY KEY,
  title       text  NOT NULL,
  date        date  NOT NULL,
  type        text  NOT NULL DEFAULT 'info',  -- 'vol' | 'info'
  time_text   text,
  pt          text,
  created_at  timestamptz DEFAULT now()
);

-- 4. thanks テーブルに is_deleted 列を追加
ALTER TABLE public.thanks
  ADD COLUMN IF NOT EXISTS is_deleted boolean NOT NULL DEFAULT false;

-- 5. coupons テーブルに不足列を追加
ALTER TABLE public.coupons
  ADD COLUMN IF NOT EXISTS code         text,
  ADD COLUMN IF NOT EXISTS novelty_name text,
  ADD COLUMN IF NOT EXISTS note         text,
  ADD COLUMN IF NOT EXISTS expires_at   date,
  ADD COLUMN IF NOT EXISTS used_at      timestamptz;

-- 6. participations テーブルに qr_code_id 列を追加
ALTER TABLE public.participations
  ADD COLUMN IF NOT EXISTS qr_code_id uuid REFERENCES public.qr_codes(id) ON DELETE SET NULL;

-- 7. profiles テーブルに email 列を追加（管理者画面でのメール表示・CSV出力用）
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS email text;
