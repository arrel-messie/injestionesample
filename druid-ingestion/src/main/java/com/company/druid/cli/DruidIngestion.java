package com.company.druid.cli;

import com.company.druid.command.BuildCommand;
import com.company.druid.command.DeployCommand;
import com.company.druid.command.StatusCommand;
import com.company.druid.command.UploadDescriptorCommand;
import com.company.druid.client.HttpClient;
import com.company.druid.config.Config;
import com.company.druid.exceptions.DruidException;
import com.company.druid.util.Validator;
import picocli.CommandLine;
import picocli.CommandLine.Command;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.concurrent.Callable;
import java.util.function.Function;

/**
 * CLI tool for managing Druid supervisor deployments.
 * 
 * <p>This application provides commands to build, deploy, and manage Druid Kafka ingestion supervisors.
 * It supports multiple environments (dev, staging, prod) and uses configuration files for flexibility.
 * 
 * <p>Available commands:
 * <ul>
 *   <li>{@code build} - Build supervisor specification JSON file</li>
 *   <li>{@code deploy} - Deploy supervisor to Druid Overlord</li>
 *   <li>{@code status} - Get supervisor status from Druid</li>
 *   <li>{@code upload-descriptor} - Placeholder for S3 descriptor upload (handled by CI)</li>
 * </ul>
 * 
 * @see com.company.druid.command.BuildCommand
 * @see com.company.druid.command.DeployCommand
 * @see com.company.druid.command.StatusCommand
 */
@Command(name = "druid-ingestion", mixinStandardHelpOptions = true, version = "1.0.0",
        description = "CLI tool for managing Druid supervisor deployments",
        subcommands = {BuildCommand.class, DeployCommand.class, StatusCommand.class, UploadDescriptorCommand.class})
public class DruidIngestion implements Callable<Integer> {

    private static final Logger log = LoggerFactory.getLogger(DruidIngestion.class);
    private static HttpClient httpClient;
    
    /**
     * Centralized error handling for all commands.
     * Catches and logs exceptions, returning appropriate exit codes.
     * 
     * @param action The command action to execute
     * @return Exit code: 0 for success, 1 for failure
     */
    public static int handleCommand(Callable<Integer> action) {
        try {
            return action.call();
        } catch (DruidException e) {
            log.error("Operation failed: {}", e.getMessage(), e);
            return 1;
        } catch (Exception e) {
            log.error("Unexpected error", e);
            return 1;
        }
    }
    
    /**
     * Helper method to load configuration and execute an action.
     * Reduces duplication in command classes by centralizing config loading.
     * 
     * @param <T> The return type of the action
     * @param env Environment name (dev, staging, prod)
     * @param action Function to execute with the loaded configuration
     * @return Result of the action function
     * @throws Exception If configuration loading or action execution fails
     */
    public static <T> T withConfig(String env, Function<Config, T> action) throws Exception {
        var root = getModuleRoot();
        Validator.validateEnvironment(env);
        var config = Config.load(root, env);
        return action.apply(config);
    }
    
    /**
     * Get the supervisor specification file path for a given datasource and environment.
     * 
     * @param root Module root directory
     * @param datasource Datasource name
     * @param env Environment name
     * @return Path to the spec file
     */
    public static Path getSpecFile(Path root, String datasource, String env) {
        return root.resolve("druid-specs/generated/supervisor-spec-" + datasource + "-" + env + ".json");
    }
    
    /**
     * Get the module root directory by searching for the "config" directory.
     * Traverses up the directory tree until the config directory is found.
     * 
     * @return Path to the module root directory, or current directory if not found
     */
    public static Path getModuleRoot() {
        var current = Paths.get("").toAbsolutePath();
        while (current != null && !Files.exists(current.resolve("config"))) {
            current = current.getParent();
        }
        return current != null ? current : Paths.get("").toAbsolutePath();
    }
    
    /**
     * Get the shared HTTP client instance.
     * 
     * @return HttpClient instance configured with default timeouts
     */
    public static HttpClient getHttpClient() {
        return httpClient;
    }

    public static void main(String[] args) {
        httpClient = new HttpClient(10, 30, 30);
        System.exit(new CommandLine(new DruidIngestion()).execute(args));
    }

    @Override
    public Integer call() {
        CommandLine.usage(this, System.out);
        return 1;
    }
}
