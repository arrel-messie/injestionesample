package com.kafka.injector.producer;

import com.google.protobuf.Timestamp;
import com.google.protobuf.util.Timestamps;
import com.company.transc.v1.PaymentTransactionEvent;
import com.kafka.injector.producer.ProtobufSerializer;
import org.apache.commons.configuration2.Configuration;
import org.apache.commons.configuration2.builder.fluent.Configurations;
import org.apache.commons.configuration2.ex.ConfigurationException;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.Producer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Properties;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Kafka Producer for Payment Transaction Events with Protobuf Schema
 */
public class TransactionProducer {
    private static final Logger logger = LoggerFactory.getLogger(TransactionProducer.class);
    
    private final Configuration config;
    private final Producer<String, PaymentTransactionEvent> producer;
    private final ScheduledExecutorService scheduler;
    private final Random random;
    private final AtomicLong messageCount;
    
    private final String topicName;
    private final int sendIntervalSeconds;
    private final long sendCount;
    private final boolean randomDataEnabled;
    private final double amountMin;
    private final double amountMax;

    public TransactionProducer(Configuration config) {
        this.config = config;
        this.producer = createProducer();
        this.scheduler = Executors.newScheduledThreadPool(1);
        this.random = new Random();
        this.messageCount = new AtomicLong(0);
        
        // Load configuration
        this.topicName = config.getString("kafka.topic.name", "settlement-transactions");
        this.sendIntervalSeconds = config.getInt("producer.send.interval.seconds", 30);
        this.sendCount = config.getLong("producer.send.count", -1);
        this.randomDataEnabled = config.getBoolean("producer.random.data.enabled", true);
        this.amountMin = config.getDouble("data.amount.min", 10.0);
        this.amountMax = config.getDouble("data.amount.max", 1000.0);
        
        logger.info("TransactionProducer initialized with configuration:");
        logger.info("  Topic: {}", topicName);
        logger.info("  Send interval: {} seconds", sendIntervalSeconds);
        logger.info("  Send count: {} (-1 = infinite)", sendCount);
        logger.info("  Random data: {}", randomDataEnabled);
    }

    private Producer<String, PaymentTransactionEvent> createProducer() {
        Properties props = new Properties();
        
        // Kafka bootstrap servers
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, 
            config.getString("kafka.bootstrap.servers", "localhost:9092"));
        props.put(ProducerConfig.CLIENT_ID_CONFIG, 
            config.getString("kafka.client.id", "transaction-producer"));
        
        // Serializers - Using raw Protobuf serializer (no Schema Registry wrapper)
        // This is compatible with Druid's Protobuf decoder
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, ProtobufSerializer.class.getName());
        
        // Note: Schema Registry is not used with raw Protobuf serialization
        // Druid expects raw Protobuf binary format without Confluent's magic byte + schema ID wrapper
        
        // Producer reliability settings
        props.put(ProducerConfig.ACKS_CONFIG, 
            config.getString("producer.acks", "all"));
        props.put(ProducerConfig.RETRIES_CONFIG, 
            config.getInt("producer.retries", 3));
        props.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, 
            config.getBoolean("producer.enable.idempotence", true));
        props.put(ProducerConfig.MAX_IN_FLIGHT_REQUESTS_PER_CONNECTION, 
            config.getInt("producer.max.in.flight.requests.per.connection", 5));
        
        // Performance settings
        props.put(ProducerConfig.BATCH_SIZE_CONFIG, 
            config.getInt("producer.batch.size", 16384));
        props.put(ProducerConfig.LINGER_MS_CONFIG, 
            config.getInt("producer.linger.ms", 10));
        props.put(ProducerConfig.BUFFER_MEMORY_CONFIG, 
            config.getLong("producer.buffer.memory", 33554432L));
        props.put(ProducerConfig.COMPRESSION_TYPE_CONFIG, 
            config.getString("producer.compression.type", "snappy"));
        
        return new KafkaProducer<>(props);
    }

    public void start() {
        logger.info("Starting TransactionProducer...");
        
        scheduler.scheduleAtFixedRate(
            this::sendTransaction,
            0,
            sendIntervalSeconds,
            TimeUnit.SECONDS
        );
        
        logger.info("TransactionProducer started. Sending messages every {} seconds", sendIntervalSeconds);
    }

    public void stop() {
        logger.info("Stopping TransactionProducer...");
        scheduler.shutdown();
        try {
            if (!scheduler.awaitTermination(10, TimeUnit.SECONDS)) {
                scheduler.shutdownNow();
                if (!scheduler.awaitTermination(5, TimeUnit.SECONDS)) {
                    logger.warn("Scheduler did not terminate");
                }
            }
        } catch (InterruptedException e) {
            scheduler.shutdownNow();
            Thread.currentThread().interrupt();
        } finally {
            producer.close();
            logger.info("TransactionProducer stopped");
        }
    }

    private void sendTransaction() {
        // Check if we've reached the send count limit
        if (sendCount > 0 && messageCount.get() >= sendCount) {
            logger.info("Reached send count limit ({}). Stopping producer.", sendCount);
            stop();
            return;
        }
        
        try {
            PaymentTransactionEvent transaction = createTransaction();
            String key = transaction.getUetr();
            
            ProducerRecord<String, PaymentTransactionEvent> record = 
                new ProducerRecord<>(topicName, key, transaction);
            
            producer.send(record, (metadata, exception) -> {
                long count = messageCount.incrementAndGet();
                if (exception != null) {
                    logger.error("Error sending message #{}: {}", count, exception.getMessage(), exception);
                } else {
                    logger.info("Message #{} sent successfully - Topic: {}, Partition: {}, Offset: {}, Key: {}", 
                        count, metadata.topic(), metadata.partition(), metadata.offset(), key);
                }
            });
            
        } catch (Exception e) {
            logger.error("Error creating or sending transaction: {}", e.getMessage(), e);
        }
    }

    private PaymentTransactionEvent createTransaction() {
        Instant now = Instant.now();
        Timestamp settlementTs = Timestamps.fromMillis(now.toEpochMilli());
        Timestamp settlementEntryTs = Timestamps.fromMillis(now.minusSeconds(60).toEpochMilli());
        Timestamp acceptanceTs = Timestamps.fromMillis(now.minusSeconds(120).toEpochMilli());
        
        String uetr = UUID.randomUUID().toString().toUpperCase();
        String rtgsBusinessDate = LocalDate.now().format(DateTimeFormatter.ISO_DATE);
        
        String[] txTypes = {"ONLINE_FUNDING", "ONLINE_DEFUNDING", "SIMPLE_PAYMENT", "COMBINED_PAYMENT"};
        String txType = randomDataEnabled
            ? txTypes[random.nextInt(txTypes.length)]
            : "SIMPLE_PAYMENT";
        
        double amount = randomDataEnabled
            ? amountMin + (amountMax - amountMin) * random.nextDouble()
            : amountMin;
        
        String[] statuses = {"PENDING", "COMPLETED", "FAILED", "CANCELLED"};
        String status = randomDataEnabled
            ? statuses[random.nextInt(statuses.length)]
            : "COMPLETED";
        
        String[] currencies = {"USD", "EUR", "GBP", "JPY"};
        String currency = randomDataEnabled
            ? currencies[random.nextInt(currencies.length)]
            : "USD";
        
        String[] bics = {"ABCDUS33", "EFGHGB2L", "IJKLFRPP", "MNOPDEFF"};
        String payerBic = randomDataEnabled
            ? bics[random.nextInt(bics.length)]
            : "ABCDUS33";
        String payeeBic = randomDataEnabled
            ? bics[random.nextInt(bics.length)]
            : "EFGHGB2L";
        
        String payerAccessManagerId = randomDataEnabled
            ? String.valueOf(1000000L + random.nextInt(9000000))
            : "1234567";
        String payeeAccessManagerId = randomDataEnabled
            ? String.valueOf(1000000L + random.nextInt(9000000))
            : "7654321";
        
        String[] reasonCodes = {"SUCCESS", "INSUFFICIENT_FUNDS", "INVALID_ACCOUNT", "TIMEOUT"};
        String reasonCode = randomDataEnabled
            ? reasonCodes[random.nextInt(reasonCodes.length)]
            : "SUCCESS";
        
        String[] paymentTypeCodes = {"ECOMM", "POS_ONLINE", "POS_OFFLINE", "SWITCHING", "P2P"};
        String paymentTypeCode = randomDataEnabled
            ? paymentTypeCodes[random.nextInt(paymentTypeCodes.length)]
            : "ECOMM";
        
        // Calculate settlement_timestamp_ms from settlementTs (milliseconds since epoch)
        long settlementTimestampMs = Timestamps.toMillis(settlementTs);
        
        return PaymentTransactionEvent.newBuilder()
            .setUetr(uetr)
            .setSettlementTs(settlementTs)
            .setSettlementEntryTs(settlementEntryTs)
            .setAcceptanceTs(acceptanceTs)
            .setRtgsBusinessDate(rtgsBusinessDate)
            .setTxType(txType)
            .setStatus(status)
            .setAmount(amount)
            .setCurrency(currency)
            .setPayerAccessManagerBic(payerBic)
            .setPayerAccessManagerId(payerAccessManagerId)
            .setPayeeAccessManagerBic(payeeBic)
            .setPayeeAccessManagerId(payeeAccessManagerId)
            .setReasonCode(reasonCode)
            .setPaymentTypeCode(paymentTypeCode)
            .setSettlementTimestampMs(settlementTimestampMs)
            .build();
    }

    public static void main(String[] args) {
        Logger logger = LoggerFactory.getLogger(TransactionProducer.class);
        
        try {
            // Load configuration
            Configurations configs = new Configurations();
            Configuration config = configs.properties("application.properties");
            
            // Create and start producer
            TransactionProducer producer = new TransactionProducer(config);
            
            // Add shutdown hook
            Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                logger.info("Shutdown hook triggered");
                producer.stop();
            }));
            
            producer.start();
            
            // Keep the main thread alive
            Thread.currentThread().join();
            
        } catch (ConfigurationException e) {
            logger.error("Configuration error: {}", e.getMessage(), e);
            System.exit(1);
        } catch (InterruptedException e) {
            logger.info("Main thread interrupted");
            Thread.currentThread().interrupt();
        } catch (Exception e) {
            logger.error("Unexpected error: {}", e.getMessage(), e);
            System.exit(1);
        }
    }
}
