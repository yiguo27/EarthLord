-- =============================================
-- 地球新主 (EarthLord) 核心数据表
-- Migration: 001_create_core_tables
-- =============================================

-- 1. profiles（用户资料）
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 启用 RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- RLS 策略：用户可以查看所有资料
CREATE POLICY "profiles_select_all" ON public.profiles
    FOR SELECT USING (true);

-- RLS 策略：用户只能更新自己的资料
CREATE POLICY "profiles_update_own" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- RLS 策略：用户只能插入自己的资料
CREATE POLICY "profiles_insert_own" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);

-- =============================================

-- 2. territories（领地）
CREATE TABLE IF NOT EXISTS public.territories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    path JSONB NOT NULL DEFAULT '[]'::jsonb,
    area DOUBLE PRECISION NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 启用 RLS
ALTER TABLE public.territories ENABLE ROW LEVEL SECURITY;

-- RLS 策略：所有人可以查看所有领地
CREATE POLICY "territories_select_all" ON public.territories
    FOR SELECT USING (true);

-- RLS 策略：用户只能插入自己的领地
CREATE POLICY "territories_insert_own" ON public.territories
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- RLS 策略：用户只能更新自己的领地
CREATE POLICY "territories_update_own" ON public.territories
    FOR UPDATE USING (auth.uid() = user_id);

-- RLS 策略：用户只能删除自己的领地
CREATE POLICY "territories_delete_own" ON public.territories
    FOR DELETE USING (auth.uid() = user_id);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_territories_user_id ON public.territories(user_id);

-- =============================================

-- 3. pois（兴趣点）
CREATE TABLE IF NOT EXISTS public.pois (
    id TEXT PRIMARY KEY,
    poi_type TEXT NOT NULL,
    name TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    discovered_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    discovered_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- 启用 RLS
ALTER TABLE public.pois ENABLE ROW LEVEL SECURITY;

-- RLS 策略：所有人可以查看所有 POI
CREATE POLICY "pois_select_all" ON public.pois
    FOR SELECT USING (true);

-- RLS 策略：已登录用户可以插入 POI
CREATE POLICY "pois_insert_authenticated" ON public.pois
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- RLS 策略：发现者可以更新 POI
CREATE POLICY "pois_update_discoverer" ON public.pois
    FOR UPDATE USING (auth.uid() = discovered_by);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_pois_type ON public.pois(poi_type);
CREATE INDEX IF NOT EXISTS idx_pois_location ON public.pois(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_pois_discovered_by ON public.pois(discovered_by);

-- =============================================

-- 自动创建用户资料的触发器函数
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 创建触发器：新用户注册时自动创建 profile
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================
-- 完成！
-- =============================================
