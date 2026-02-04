-- ============================================
-- 第22天：玩家位置上报系统
-- 用于检测附近玩家密度，动态调整POI数量
-- ============================================

-- 1. 启用 PostGIS 扩展（如果尚未启用）
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. 创建 player_locations 表
CREATE TABLE IF NOT EXISTS player_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

    -- 位置信息
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy DOUBLE PRECISION,           -- GPS精度（米）

    -- 状态信息
    is_online BOOLEAN DEFAULT true,      -- 是否在线
    last_report_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),  -- 最后上报时间

    -- 元数据
    device_id TEXT,                      -- 设备标识
    app_version TEXT,                    -- App版本

    -- 时间戳
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- 约束：每个用户只有一条记录
    UNIQUE(user_id)
);

-- 3. 创建索引
-- 地理空间索引（用于范围查询）
CREATE INDEX IF NOT EXISTS idx_player_locations_geo
    ON player_locations
    USING GIST (ST_SetSRID(ST_MakePoint(longitude, latitude), 4326));

-- 在线状态索引（用于过滤在线玩家）
CREATE INDEX IF NOT EXISTS idx_player_locations_online
    ON player_locations(is_online, last_report_at);

-- 用户ID索引
CREATE INDEX IF NOT EXISTS idx_player_locations_user
    ON player_locations(user_id);

-- 4. 启用 RLS
ALTER TABLE player_locations ENABLE ROW LEVEL SECURITY;

-- 5. RLS 策略：用户只能管理自己的位置
DROP POLICY IF EXISTS "Users can manage own location" ON player_locations;
CREATE POLICY "Users can manage own location" ON player_locations
    FOR ALL USING (auth.uid() = user_id);

-- 6. 创建 RPC 函数：查询附近玩家数量
-- 隐私保护：只返回数量，不暴露具体位置
CREATE OR REPLACE FUNCTION get_nearby_player_count(
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_radius_meters INTEGER DEFAULT 1000,  -- 默认1公里
    p_exclude_user_id UUID DEFAULT NULL    -- 排除自己
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER  -- 以函数所有者权限执行，绕过RLS
AS $$
DECLARE
    v_count INTEGER;
    v_online_threshold INTERVAL := INTERVAL '5 minutes';  -- 5分钟内算在线
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM player_locations
    WHERE
        -- 在线判断：5分钟内有上报
        last_report_at > (NOW() - v_online_threshold)
        AND is_online = true
        -- 排除自己
        AND (p_exclude_user_id IS NULL OR user_id != p_exclude_user_id)
        -- 距离计算（使用PostGIS的ST_DWithin）
        AND ST_DWithin(
            ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
            ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography,
            p_radius_meters
        );

    RETURN COALESCE(v_count, 0);
END;
$$;

-- 7. 添加注释
COMMENT ON TABLE player_locations IS '玩家位置表 - 用于附近玩家密度检测';
COMMENT ON COLUMN player_locations.latitude IS '纬度';
COMMENT ON COLUMN player_locations.longitude IS '经度';
COMMENT ON COLUMN player_locations.accuracy IS 'GPS精度（米）';
COMMENT ON COLUMN player_locations.is_online IS '是否在线（进入后台时设为false）';
COMMENT ON COLUMN player_locations.last_report_at IS '最后上报时间（5分钟内算在线）';
COMMENT ON FUNCTION get_nearby_player_count IS '查询附近在线玩家数量（隐私保护：只返回数量）';
