package com.healthcoach.storage;

import com.google.cloud.storage.BlobId;
import com.google.cloud.storage.BlobInfo;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.UUID;

/**
 * GCS upload service — claim-check pattern for OmniChat file uploads.
 *
 * Uploads MultipartFile to GCS and returns the gs:// URI so the
 * RabbitMQ message stays small (URL reference, not embedded bytes).
 *
 * Graceful local-dev fallback: if GCS_BUCKET_NAME is blank or GCS
 * credentials are absent, returns null and the caller falls back to
 * base64 embedding (existing behaviour, fine for dev/test).
 *
 * Production bucket layout:
 *   gs://{bucket}/food/{userId}/{uuid}.jpg
 *   gs://{bucket}/medical/{userId}/{uuid}.pdf
 */
@Service
public class GcsStorageService {

    private static final Logger log = LoggerFactory.getLogger(GcsStorageService.class);

    @Value("${app.gcs.bucket-name:}")
    private String bucketName;

    /**
     * Upload a food image and return its gs:// URI.
     * Returns null if GCS is not configured (dev fallback).
     */
    public String uploadFoodImage(MultipartFile file, Long userId) {
        return upload(file, "food/" + userId, contentTypeOf(file));
    }

    /**
     * Upload a medical PDF and return its gs:// URI.
     * Returns null if GCS is not configured (dev fallback).
     */
    public String uploadMedicalPdf(MultipartFile file, Long userId) {
        return upload(file, "medical/" + userId, "application/pdf");
    }

    // ── internals ────────────────────────────────────────────────────────────

    private String upload(MultipartFile file, String prefix, String contentType) {
        if (bucketName == null || bucketName.isBlank()) {
            log.debug("GCS_BUCKET_NAME not set — skipping GCS upload, falling back to base64");
            return null;
        }
        if (file == null || file.isEmpty()) return null;

        try {
            Storage storage = StorageOptions.getDefaultInstance().getService();
            String objectName = prefix + "/" + UUID.randomUUID() + extension(file);
            BlobId blobId = BlobId.of(bucketName, objectName);
            BlobInfo blobInfo = BlobInfo.newBuilder(blobId)
                    .setContentType(contentType)
                    .build();
            storage.create(blobInfo, file.getBytes());
            String uri = "gs://" + bucketName + "/" + objectName;
            log.debug("Uploaded {} to {}", file.getOriginalFilename(), uri);
            return uri;
        } catch (Exception e) {
            log.warn("GCS upload failed — falling back to base64: {}", e.getMessage());
            return null;
        }
    }

    private String contentTypeOf(MultipartFile file) {
        String ct = file.getContentType();
        return ct != null ? ct : "application/octet-stream";
    }

    private String extension(MultipartFile file) {
        String name = file.getOriginalFilename();
        if (name != null && name.contains(".")) {
            return name.substring(name.lastIndexOf('.'));
        }
        return "";
    }
}
