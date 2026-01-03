package com.company.druid.command;

import com.company.druid.cli.DruidIngestion;
import com.company.druid.config.Config;
import com.company.druid.spec.SpecBuilder;
import com.fasterxml.jackson.databind.ObjectMapper;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.Callable;

/**
 * Command to build a Druid supervisor specification JSON file.
 * 
 * <p>This command generates a supervisor spec file from the configuration and schema.
 * The spec file can be used to deploy the supervisor to Druid Overlord.
 * 
 * <p>Example usage:
 * <pre>{@code
 * java -jar druid-ingestion.jar build -e dev
 * java -jar druid-ingestion.jar build -e staging -o /path/to/spec.json
 * }</pre>
 */
@Command(name = "build", description = "Build supervisor spec")
public class BuildCommand implements Callable<Integer> {
    private static final Logger log = LoggerFactory.getLogger(BuildCommand.class);
    private static final SpecBuilder BUILDER = new SpecBuilder();
    private static final ObjectMapper MAPPER = com.company.druid.client.HttpClient.mapper();

    @Option(names = {"-e", "--env"}, required = true, description = "Environment (dev, staging, prod)") 
    String env;
    
    @Option(names = {"-o", "--output"}, description = "Output file path") 
    Path output;

    /**
     * Build supervisor specification file.
     * Extracted as a static method for reuse by DeployCommand.
     * 
     * @param config Configuration to use for building the spec
     * @param env Environment name (used for Kafka consumer group ID)
     * @param output Path where the spec file should be written
     * @throws Exception If file writing fails
     */
    public static void buildSpec(Config config, String env, Path output) throws Exception {
        Files.createDirectories(output.getParent());
        MAPPER.writerWithDefaultPrettyPrinter().writeValue(output.toFile(), BUILDER.build(config, env));
    }

    @Override
    public Integer call() {
        return DruidIngestion.handleCommand(() -> {
            var config = DruidIngestion.withConfig(env, c -> c);
            var root = DruidIngestion.getModuleRoot();
            var out = output != null ? output : DruidIngestion.getSpecFile(root, config.druid().datasource(), env);
            buildSpec(config, env, out);
            log.info("Supervisor spec built: {}", out);
            System.out.println(out);
            return 0;
        });
    }
}
