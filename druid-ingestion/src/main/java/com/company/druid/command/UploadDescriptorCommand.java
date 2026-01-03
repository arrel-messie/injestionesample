package com.company.druid.command;

import com.company.druid.cli.DruidIngestion;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.concurrent.Callable;

/**
 * Upload Protobuf descriptor to S3 command
 * Note: Actual upload is handled by GitLab CI using AWS CLI
 * This command is a placeholder for documentation purposes
 */
@Command(name = "upload-descriptor", description = "Upload Protobuf descriptor to S3 (handled by GitLab CI)")
public class UploadDescriptorCommand implements Callable<Integer> {
    private static final Logger log = LoggerFactory.getLogger(UploadDescriptorCommand.class);

    @Option(names = {"-e", "--env"}, required = true, description = "Environment (dev, staging, prod)") 
    String env;

    @Override
    public Integer call() {
        return DruidIngestion.handleCommand(() -> {
            log.info("S3 upload is handled by GitLab CI using AWS CLI. See .gitlab-ci.yml for implementation.");
            return 0;
        });
    }
}
