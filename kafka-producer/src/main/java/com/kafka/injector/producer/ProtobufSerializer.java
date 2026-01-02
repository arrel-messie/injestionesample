package com.kafka.injector.producer;

import com.company.transc.v1.PaymentTransactionEvent;
import org.apache.kafka.common.serialization.Serializer;

import java.util.Map;

/**
 * Simple Protobuf serializer that serializes messages directly to bytes
 * without Confluent Schema Registry wrapper (magic byte + schema ID).
 * This is compatible with Druid's Protobuf decoder.
 */
public class ProtobufSerializer implements Serializer<PaymentTransactionEvent> {
    
    @Override
    public void configure(Map<String, ?> configs, boolean isKey) {
        // No configuration needed
    }
    
    @Override
    public byte[] serialize(String topic, PaymentTransactionEvent data) {
        if (data == null) {
            return null;
        }
        // Serialize directly to Protobuf binary format
        return data.toByteArray();
    }
    
    @Override
    public void close() {
        // No resources to close
    }
}

