-- ================================================
-- WaWa アプリ RLS（行レベルセキュリティ）設定
-- Supabase SQL Editor で実行してください
--
-- 前提：schema.sql を先に実行済みであること
-- ================================================

-- ======== 管理者チェック関数 ========
-- auth.uid() が profiles.role='admin' のユーザーか判定
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

-- ======== profiles ========
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 認証ユーザー全員が読める（感謝送信先リスト表示等のため）
CREATE POLICY "profiles_select"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);

-- 自分のプロフィール、または管理者が更新可（total_pt・role更新を含む）
CREATE POLICY "profiles_update"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (id = auth.uid() OR public.is_admin())
  WITH CHECK (id = auth.uid() OR public.is_admin());

-- 自分のみ登録可（初回オンボーディング）
CREATE POLICY "profiles_insert"
  ON public.profiles FOR INSERT
  TO authenticated
  WITH CHECK (id = auth.uid());

-- 管理者のみ削除可
CREATE POLICY "profiles_delete"
  ON public.profiles FOR DELETE
  TO authenticated
  USING (public.is_admin());


-- ======== participations ========
ALTER TABLE public.participations ENABLE ROW LEVEL SECURITY;

-- 自分の参加記録のみ、または管理者
CREATE POLICY "participations_select"
  ON public.participations FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

-- 自分の記録のみ挿入可
CREATE POLICY "participations_insert"
  ON public.participations FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- 管理者のみ更新・削除
CREATE POLICY "participations_update"
  ON public.participations FOR UPDATE
  TO authenticated
  USING (public.is_admin());

CREATE POLICY "participations_delete"
  ON public.participations FOR DELETE
  TO authenticated
  USING (public.is_admin());


-- ======== thanks ========
ALTER TABLE public.thanks ENABLE ROW LEVEL SECURITY;

-- 認証ユーザー全員が読める（ありがとうフィード）
CREATE POLICY "thanks_select"
  ON public.thanks FOR SELECT
  TO authenticated
  USING (true);

-- 自分が送信者として挿入可
CREATE POLICY "thanks_insert"
  ON public.thanks FOR INSERT
  TO authenticated
  WITH CHECK (from_user_id = auth.uid());

-- 管理者のみ更新（is_deleted など）・削除
CREATE POLICY "thanks_update"
  ON public.thanks FOR UPDATE
  TO authenticated
  USING (public.is_admin());

CREATE POLICY "thanks_delete"
  ON public.thanks FOR DELETE
  TO authenticated
  USING (public.is_admin());


-- ======== coupons ========
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

-- 自分のクーポンのみ、または管理者
CREATE POLICY "coupons_select"
  ON public.coupons FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

-- 自分への発行または管理者による発行
CREATE POLICY "coupons_insert"
  ON public.coupons FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid() OR public.is_admin());

-- 自分のクーポンの更新（使用済みにする）または管理者
CREATE POLICY "coupons_update"
  ON public.coupons FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

-- 管理者のみ削除
CREATE POLICY "coupons_delete"
  ON public.coupons FOR DELETE
  TO authenticated
  USING (public.is_admin());


-- ======== point_logs ========
ALTER TABLE public.point_logs ENABLE ROW LEVEL SECURITY;

-- 自分のポイント履歴のみ、または管理者
CREATE POLICY "point_logs_select"
  ON public.point_logs FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

-- 自分への付与（QRスキャン等）または管理者による手動付与
CREATE POLICY "point_logs_insert"
  ON public.point_logs FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid() OR public.is_admin());

-- 管理者のみ更新・削除
CREATE POLICY "point_logs_update"
  ON public.point_logs FOR UPDATE
  TO authenticated
  USING (public.is_admin());

CREATE POLICY "point_logs_delete"
  ON public.point_logs FOR DELETE
  TO authenticated
  USING (public.is_admin());


-- ======== notices ========
ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;

-- 認証ユーザー全員が読める
CREATE POLICY "notices_select"
  ON public.notices FOR SELECT
  TO authenticated
  USING (true);

-- 管理者のみ投稿・更新・削除
CREATE POLICY "notices_insert"
  ON public.notices FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY "notices_update"
  ON public.notices FOR UPDATE
  TO authenticated
  USING (public.is_admin());

CREATE POLICY "notices_delete"
  ON public.notices FOR DELETE
  TO authenticated
  USING (public.is_admin());


-- ======== volunteers ========
ALTER TABLE public.volunteers ENABLE ROW LEVEL SECURITY;

-- 認証ユーザーは公開中のみ読める。管理者は全部。
CREATE POLICY "volunteers_select"
  ON public.volunteers FOR SELECT
  TO authenticated
  USING (status != 'hidden' OR public.is_admin());

-- 管理者のみ作成・更新・削除
CREATE POLICY "volunteers_insert"
  ON public.volunteers FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY "volunteers_update"
  ON public.volunteers FOR UPDATE
  TO authenticated
  USING (public.is_admin());

CREATE POLICY "volunteers_delete"
  ON public.volunteers FOR DELETE
  TO authenticated
  USING (public.is_admin());


-- ======== qr_codes ========
ALTER TABLE public.qr_codes ENABLE ROW LEVEL SECURITY;

-- 認証ユーザーは読める（QRスキャン検証のため）
CREATE POLICY "qr_codes_select"
  ON public.qr_codes FOR SELECT
  TO authenticated
  USING (true);

-- 管理者のみ作成・更新・削除
CREATE POLICY "qr_codes_insert"
  ON public.qr_codes FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY "qr_codes_update"
  ON public.qr_codes FOR UPDATE
  TO authenticated
  USING (public.is_admin());

CREATE POLICY "qr_codes_delete"
  ON public.qr_codes FOR DELETE
  TO authenticated
  USING (public.is_admin());


-- ======== novelties ========
ALTER TABLE public.novelties ENABLE ROW LEVEL SECURITY;

-- 認証ユーザー全員が読める
CREATE POLICY "novelties_select"
  ON public.novelties FOR SELECT
  TO authenticated
  USING (true);

-- 管理者のみ更新・挿入
CREATE POLICY "novelties_insert"
  ON public.novelties FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY "novelties_update"
  ON public.novelties FOR UPDATE
  TO authenticated
  USING (public.is_admin());


-- ======== calendar_events ========
ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;

-- 認証ユーザー全員が読める
CREATE POLICY "calendar_events_select"
  ON public.calendar_events FOR SELECT
  TO authenticated
  USING (true);

-- 管理者のみ作成・更新・削除
CREATE POLICY "calendar_events_insert"
  ON public.calendar_events FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY "calendar_events_update"
  ON public.calendar_events FOR UPDATE
  TO authenticated
  USING (public.is_admin());

CREATE POLICY "calendar_events_delete"
  ON public.calendar_events FOR DELETE
  TO authenticated
  USING (public.is_admin());


-- ================================================
-- ⚠️  注意事項
-- ================================================
-- 1. total_pt はクライアントから直接更新できてしまうため、
--    本番運用では Supabase Edge Functions 経由での
--    ポイント付与に切り替えることを推奨します。
--
-- 2. role フィールドも同様にクライアントから自己更新可能です。
--    管理者昇格は Supabase ダッシュボードで直接行うか、
--    Edge Function で保護することを推奨します。
-- ================================================
