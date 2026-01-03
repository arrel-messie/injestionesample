package com.company.druid;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.file.Path;

/**
 * Placeholder for S3 upload functionality
 * Actual S3 upload is handled by GitLab CI using AWS CLI
 */
public class S3Uploader {
    private static final Logger log = LoggerFactory.getLogger(S3Uploader.class);

    /**
     * Placeholder for S3 upload - actual upload is done via GitLab CI using AWS CLI
     * @param filePath Local file path
     * @param bucket S3 bucket name
     * @param key S3 object key
     * @param endpoint S3 endpoint URL (optional, for MinIO or custom S3)
     * @param accessKey AWS access key (not used, AWS CLI uses env vars)
     * @param secretKey AWS secret key (not used, AWS CLI uses env vars)
     * @param region AWS region
     */
    public static void upload(Path filePath, String bucket, String key, 
                             String endpoint, String accessKey, String secretKey, String region) {
        // Note: Actual S3 upload is handled by GitLab CI using AWS CLI
        // This method exists for future Java-based upload if needed
        log.info("S3 upload should be done via GitLab CI using AWS CLI");
        log.info("Would upload {} to s3://{}/{}", filePath, bucket, key);
        throw new UnsupportedOperationException(
            "S3 upload is handled by GitLab CI. Use AWS CLI in pipeline instead."
        );
    }
}
