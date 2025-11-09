-- 数据库状态验证脚本
-- 验证所有数据库及其扩展的安装状态

-- 记录开始时间
\echo '开始验证数据库状态...'

-- 1. 列出所有数据库
\echo '=== 数据库列表 ==='
SELECT
    datname as database_name,
    datistemplate as is_template,
    datallowconn as allows_connections,
    pg_size_pretty(pg_database_size(datname)) as size
FROM pg_database
WHERE datistemplate = false
ORDER BY datname;

-- 2. 验证每个数据库的扩展状态
\echo ''
\echo '=== 各数据库扩展状态 ==='

-- 默认数据库扩展状态
\echo '默认数据库扩展:'
SELECT
    extname,
    extversion
FROM pg_extension
ORDER BY extname;

-- 验证 lunchbox 数据库扩展
\c lunchbox
\echo ''
\echo 'lunchbox 数据库扩展:'
SELECT
    extname,
    extversion
FROM pg_extension
ORDER BY extname;

-- 验证 shop 数据库扩展
\c shop
\echo ''
\echo 'shop 数据库扩展:'
SELECT
    extname,
    extversion
FROM pg_extension
ORDER BY extname;

-- 验证 domost 数据库扩展
\c domost
\echo ''
\echo 'domost 数据库扩展:'
SELECT
    extname,
    extversion
FROM pg_extension
ORDER BY extname;

-- 验证 authelia 数据库扩展
\c authelia
\echo ''
\echo 'authelia 数据库扩展:'
SELECT
    extname,
    extversion
FROM pg_extension
ORDER BY extname;

-- 切换回默认数据库
\c postgres

-- 3. 验证 PostGIS 功能
\echo ''
\echo '=== PostGIS 功能验证 ==='

-- 在所有数据库中测试 PostGIS 功能
DO $$
DECLARE
    db_name text;
    test_result text;
BEGIN
    FOR db_name IN SELECT datname FROM pg_database WHERE datistemplate = false
    LOOP
        EXECUTE format('
            SELECT
                ''%s'' as database,
                ST_Area(ST_GeomFromText(''POLYGON((0 0, 10 0, 10 10, 0 10, 0 0))'')) > 0 as geometry_works,
                ST_Transform(ST_GeomFromText(''POINT(0 0)'', 4326), 3857) IS NOT NULL as projection_works
            FROM %I.pg_extension
            WHERE extname = ''postgis''
            LIMIT 1',
            db_name, db_name
        ) INTO test_result;

        IF test_result IS NOT NULL THEN
            RAISE NOTICE '数据库 %: PostGIS 功能正常', db_name;
        ELSE
            RAISE NOTICE '数据库 %: PostGIS 扩展未找到', db_name;
        END IF;
    END LOOP;
END $$;

-- 4. 验证 pgvector 功能
\echo ''
\echo '=== pgvector 功能验证 ==='

-- 在所有数据库中测试 pgvector 功能
DO $$
DECLARE
    db_name text;
    test_result text;
BEGIN
    FOR db_name IN SELECT datname FROM pg_database WHERE datistemplate = false
    LOOP
        EXECUTE format('
            SELECT
                ''%s'' as database,
                (''[1,2,3]''::vector <-> ''[4,5,6]''::vector) > 0 as vector_distance_works
            FROM %I.pg_extension
            WHERE extname = ''vector''
            LIMIT 1',
            db_name, db_name
        ) INTO test_result;

        IF test_result IS NOT NULL THEN
            RAISE NOTICE '数据库 %: pgvector 功能正常', db_name;
        ELSE
            RAISE NOTICE '数据库 %: pgvector 扩展未找到', db_name;
        END IF;
    END LOOP;
END $$;

-- 5. 数据库连接统计
\echo ''
\echo '=== 数据库连接统计 ==='
SELECT
    datname,
    numbackends as active_connections,
    xact_commit as transactions_committed,
    xact_rollback as transactions_rolled_back
FROM pg_stat_database
WHERE datistemplate = false;

-- 6. 扩展依赖关系验证
\echo ''
\echo '=== 扩展依赖关系 ==='
SELECT
    e.extname as extension,
    array_agg(d.deptype) as dependency_types,
    COUNT(*) as dependency_count
FROM pg_extension e
LEFT JOIN pg_depend d ON e.oid = d.refobjid
WHERE e.extname IN ('postgis', 'postgis_topology', 'postgis_raster', 'fuzzystrmatch', 'vector')
GROUP BY e.extname
ORDER BY e.extname;

-- 最终验证总结
\echo ''
\echo '=== 数据库验证总结 ==='
SELECT
    COUNT(DISTINCT datname) as total_databases,
    COUNT(DISTINCT CASE WHEN extname = 'postgis' THEN datname END) as databases_with_postgis,
    COUNT(DISTINCT CASE WHEN extname = 'vector' THEN datname END) as databases_with_vector,
    '验证完成' as status
FROM (
    SELECT datname, extname
    FROM pg_database d
    CROSS JOIN LATERAL (
        SELECT extname
        FROM dblink('dbname=' || d.datname, 'SELECT extname FROM pg_extension') AS t(extname text)
    ) ext
    WHERE d.datistemplate = false
) all_extensions;

\echo '数据库验证完成！'
