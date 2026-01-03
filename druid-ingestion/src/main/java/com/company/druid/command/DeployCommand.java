package com.company.druid.command;

import com.company.druid.cli.DruidIngestion;
import com.company.druid.config.Config;
import com.company.druid.util.Validator;
import okhttp3.*;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.Callable;

/**
 * Command to deploy a Druid supervisor to the Druid Overlord.
 * 
 * <p>This command builds the supervisor spec (if not already built) and posts it to Druid Overlord.
 * The supervisor will start ingesting data from Kafka according to the configuration.
 * 
 * <p>Example usage:
 * <pre>{@code
 * java -jar druid-ingestion.jar deploy -e dev
 * }</pre>
 */
@Command(name = "deploy", description = "Deploy supervisor")
public class DeployCommand implements Callable<Integer> {
    private static final Logger log = LoggerFactory.getLogger(DeployCommand.class);

    @Option(names = {"-e", "--env"}, required = true, description = "Environment (dev, staging, prod)") 
    String env;

    @Override
    public Integer call() {
        return DruidIngestion.handleCommand(() -> {
            var root = DruidIngestion.getModuleRoot();
            Validator.validateEnvironment(env);
            var config = Config.load(root, env);
            var specFile = DruidIngestion.getSpecFile(root, config.druid().datasource(), env);
            
            if (!Files.exists(specFile)) {
                log.info("Spec file not found, building it first...");
                BuildCommand.buildSpec(config, env, specFile);
            }
            
            Validator.validateUrl(config.druid().url(), "Druid Overlord");
            
            var request = new Request.Builder()
                .url(config.druid().url() + "/druid/indexer/v1/supervisor")
                .post(RequestBody.create(Files.readString(specFile), MediaType.get("application/json")))
                .build();
            
            var response = DruidIngestion.getHttpClient().execute(request, 3);
            log.info("Supervisor deployed successfully for datasource: {} - Response: {}", config.druid().datasource(), response);
            return 0;
        });
    }
}
