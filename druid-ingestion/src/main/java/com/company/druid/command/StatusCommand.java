package com.company.druid.command;

import com.company.druid.cli.DruidIngestion;
import com.company.druid.config.Config;
import com.company.druid.util.Validator;
import okhttp3.Request;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.concurrent.Callable;

/**
 * Command to get the status of a Druid supervisor.
 * 
 * <p>This command queries the Druid Overlord API to retrieve the current status
 * of the supervisor, including running tasks, ingestion rate, and any errors.
 * 
 * <p>Example usage:
 * <pre>{@code
 * java -jar druid-ingestion.jar status -e dev
 * }</pre>
 */
@Command(name = "status", description = "Get supervisor status")
public class StatusCommand implements Callable<Integer> {
    private static final Logger log = LoggerFactory.getLogger(StatusCommand.class);

    @Option(names = {"-e", "--env"}, required = true, description = "Environment (dev, staging, prod)") 
    String env;

    @Override
    public Integer call() {
        return DruidIngestion.handleCommand(() -> {
            var config = DruidIngestion.withConfig(env, c -> c);
            var druid = config.druid();
            Validator.validateUrl(druid.url(), "Druid Overlord");
            
            var request = new Request.Builder()
                .url(druid.url() + "/druid/indexer/v1/supervisor/" + druid.datasource() + "/status")
                .get()
                .build();
            
            var prettyJson = DruidIngestion.getHttpClient().executeAndPrettyPrint(request, 2);
            System.out.println(prettyJson);
            return 0;
        });
    }
}
