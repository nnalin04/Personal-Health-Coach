package com.healthcoach.chat;

/**
 * Value type returned by {@link OmniChatService#handleUpload}.
 * The controller maps each kind to the correct HTTP status + response body.
 */
public record UploadResult(
        Kind   kind,
        String taskId,
        String message,        // confirmation text (PROFILE_UPDATED) or error detail (ERROR)
        int    estimatedSecs   // only meaningful for ACCEPTED
) {

    public enum Kind { ACCEPTED, PROFILE_UPDATED, ERROR }

    public static UploadResult accepted(String taskId, int estimatedSecs) {
        return new UploadResult(Kind.ACCEPTED, taskId, null, estimatedSecs);
    }

    public static UploadResult profileUpdated(String taskId, String confirmationMessage) {
        return new UploadResult(Kind.PROFILE_UPDATED, taskId, confirmationMessage, 0);
    }

    public static UploadResult error(String errorMessage) {
        return new UploadResult(Kind.ERROR, null, errorMessage, 0);
    }
}
