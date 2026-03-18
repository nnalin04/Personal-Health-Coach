package com.healthcoach.common;

import java.util.List;
import org.springframework.data.domain.Page;

/**
 * Generic paginated API response envelope.
 *
 * <pre>
 * {
 *   "content": [...],
 *   "page": 0,
 *   "size": 50,
 *   "totalElements": 312,
 *   "totalPages": 7,
 *   "last": false
 * }
 * </pre>
 */
public record PagedResponse<T>(
        List<T> content,
        int page,
        int size,
        long totalElements,
        int totalPages,
        boolean last
) {
    public static <T> PagedResponse<T> from(Page<T> page) {
        return new PagedResponse<>(
                page.getContent(),
                page.getNumber(),
                page.getSize(),
                page.getTotalElements(),
                page.getTotalPages(),
                page.isLast()
        );
    }
}
