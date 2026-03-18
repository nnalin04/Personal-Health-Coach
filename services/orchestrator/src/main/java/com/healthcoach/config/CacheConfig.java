package com.healthcoach.config;

import com.github.benmanes.caffeine.cache.Caffeine;
import java.util.concurrent.TimeUnit;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.caffeine.CaffeineCache;
import org.springframework.cache.support.SimpleCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

/**
 * Per-cache Caffeine configuration.
 *
 * Using refreshAfterWrite instead of expireAfterWrite prevents the cache-stampede
 * problem: when the TTL elapses, the first requesting thread triggers an async
 * reload while all concurrent threads still receive the stale (but non-null) value.
 * Only one thread does the expensive Gemini call — not N threads simultaneously.
 *
 * Cache specs:
 *   healthSummary   — refreshAfterWrite=4m, expireAfterWrite=5m  (data summary, cheap DB queries)
 *   healthSummaryAi — refreshAfterWrite=25m, expireAfterWrite=30m (Gemini AI insights, expensive)
 */
@Configuration
@EnableCaching
public class CacheConfig {

    @Bean
    public CacheManager cacheManager() {
        CaffeineCache healthSummary = buildCache(
                "healthSummary",
                /* refreshAfterWrite= */ 4,
                /* expireAfterWrite=  */ 5,
                TimeUnit.MINUTES,
                10_000
        );

        CaffeineCache healthSummaryAi = buildCache(
                "healthSummaryAi",
                /* refreshAfterWrite= */ 25,
                /* expireAfterWrite=  */ 30,
                TimeUnit.MINUTES,
                10_000
        );

        SimpleCacheManager manager = new SimpleCacheManager();
        manager.setCaches(List.of(healthSummary, healthSummaryAi));
        return manager;
    }

    /**
     * Builds a Caffeine cache with:
     *  - refreshAfterWrite: serves stale value to concurrent callers while one async reload runs
     *  - expireAfterWrite:  hard eviction ceiling (prevents indefinitely-stale entries)
     *  - maximumSize:       memory cap
     */
    private static CaffeineCache buildCache(
            String name,
            long refreshAfterWrite, long expireAfterWrite,
            TimeUnit unit, long maxSize
    ) {
        return new CaffeineCache(name,
                Caffeine.newBuilder()
                        .maximumSize(maxSize)
                        .refreshAfterWrite(refreshAfterWrite, unit)
                        .expireAfterWrite(expireAfterWrite, unit)
                        .recordStats()          // exposes hit/miss via Actuator /actuator/metrics
                        .build(key -> null)     // null loader — Spring's @Cacheable handles population
        );
    }
}
