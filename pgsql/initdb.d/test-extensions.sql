-- PostGIS 扩展功能测试脚本
-- 验证所有已安装的扩展是否正常工作

-- 记录开始时间
\echo '开始测试 PostGIS 扩展功能...'

-- 1. 测试基础 PostGIS 功能
\echo '1. 测试基础 PostGIS 几何功能...'
SELECT
    '基础几何功能' as test_category,
    ST_Area(ST_GeomFromText('POLYGON((0 0, 10 0, 10 10, 0 10, 0 0))')) as polygon_area,
    ST_Distance(
        ST_GeomFromText('POINT(0 0)'),
        ST_GeomFromText('POINT(3 4)')
    ) as point_distance,
    ST_Intersects(
        ST_GeomFromText('POLYGON((0 0, 5 0, 5 5, 0 5, 0 0))'),
        ST_GeomFromText('POLYGON((3 3, 8 3, 8 8, 3 8, 3 3))')
    ) as polygons_intersect;

-- 2. 测试 PostGIS Topology 功能
\echo '2. 测试 PostGIS Topology 功能...'
SELECT
    '拓扑功能' as test_category,
    topology.CreateTopology('test_topology', 4326) IS NOT NULL as topology_created,
    (SELECT COUNT(*) FROM topology.topology WHERE name = 'test_topology') as topology_count;

-- 清理拓扑测试数据
SELECT topology.DropTopology('test_topology');

-- 3. 测试 PostGIS Raster 功能
\echo '3. 测试 PostGIS Raster 功能...'
SELECT
    '栅格功能' as test_category,
    ST_MakeEmptyRaster(100, 100, 0, 0, 1, -1, 0, 0, 4326) IS NOT NULL as raster_created,
    ST_Width(ST_MakeEmptyRaster(100, 100, 0, 0, 1, -1, 0, 0, 4326)) as raster_width,
    ST_Height(ST_MakeEmptyRaster(100, 100, 0, 0, 1, -1, 0, 0, 4326)) as raster_height;

-- 4. 测试 Fuzzy String Match 功能
\echo '4. 测试模糊字符串匹配功能...'
SELECT
    '模糊匹配' as test_category,
    levenshtein('hello', 'hallo') as levenshtein_distance,
    levenshtein_less_equal('hello', 'hallo', 2) as levenshtein_limited,
    difference('hello', 'hallo') as soundex_difference,
    metaphone('hello', 4) as metaphone_code;

-- 5. 测试 pgvector 功能
\echo '5. 测试 pgvector 向量功能...'
SELECT
    '向量功能' as test_category,
    '[1,2,3]'::vector as sample_vector,
    '[1,2,3]'::vector <-> '[4,5,6]'::vector as vector_distance,
    array_dims('[1,2,3]'::vector::float8[]) as vector_dimensions;

-- 6. 验证所有扩展状态
\echo '6. 验证所有扩展状态...'
SELECT
    extname,
    extversion,
    CASE
        WHEN extname = 'postgis' THEN '核心空间数据扩展'
        WHEN extname = 'postgis_topology' THEN '拓扑数据处理'
        WHEN extname = 'postgis_raster' THEN '栅格数据处理'
        WHEN extname = 'fuzzystrmatch' THEN '模糊字符串匹配'
        WHEN extname = 'vector' THEN '向量相似度搜索'
        ELSE '其他扩展'
    END as description
FROM pg_extension
WHERE extname IN ('postgis', 'postgis_topology', 'postgis_raster', 'fuzzystrmatch', 'vector')
ORDER BY extname;

-- 7. 测试坐标投影功能 (PROJ)
\echo '7. 测试坐标投影功能...'
SELECT
    '坐标投影' as test_category,
    ST_Transform(ST_GeomFromText('POINT(-122.4194 37.7749)', 4326), 3857) as transformed_point,
    ST_SRID(ST_Transform(ST_GeomFromText('POINT(-122.4194 37.7749)', 4326), 3857)) as target_srid;

-- 8. 测试几何引擎功能 (GEOS)
\echo '8. 测试几何引擎功能...'
SELECT
    '几何引擎' as test_category,
    ST_IsValid(ST_GeomFromText('POLYGON((0 0, 10 0, 10 10, 0 10, 0 0))')) as valid_geometry,
    ST_IsSimple(ST_GeomFromText('LINESTRING(0 0, 10 10)')) as simple_geometry,
    ST_Contains(
        ST_GeomFromText('POLYGON((0 0, 10 0, 10 10, 0 10, 0 0))'),
        ST_GeomFromText('POINT(5 5)')
    ) as contains_point;

-- 最终测试总结
\echo '=== 扩展功能测试总结 ==='
SELECT
    COUNT(*) as total_extensions,
    SUM(CASE WHEN extname IN ('postgis', 'postgis_topology', 'postgis_raster', 'fuzzystrmatch', 'vector') THEN 1 ELSE 0 END) as tested_extensions,
    '所有扩展功能测试完成' as status
FROM pg_extension
WHERE extname IN ('postgis', 'postgis_topology', 'postgis_raster', 'fuzzystrmatch', 'vector');

\echo 'PostGIS 扩展功能测试完成！'
