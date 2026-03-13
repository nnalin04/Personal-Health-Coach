package com.healthcoach.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * RabbitMQ topology for the Health OS event-driven pipeline.
 *
 * Exchange: health_os.tasks (topic)
 *   Routing keys:
 *     food.vision   → food-vision-queue   (Gemini Vision pipeline)
 *     medical.ocr   → medical-ocr-queue   (Document AI OCR pipeline)
 *     rag.correlate → rag-insight-queue   (LangChain + pgvector RAG)
 */
@Configuration
public class RabbitMqConfig {

    public static final String EXCHANGE      = "health_os.tasks";
    public static final String FOOD_QUEUE    = "food-vision-queue";
    public static final String MEDICAL_QUEUE = "medical-ocr-queue";
    public static final String RAG_QUEUE     = "rag-insight-queue";

    public static final String FOOD_KEY    = "food.vision";
    public static final String MEDICAL_KEY = "medical.ocr";
    public static final String RAG_KEY     = "rag.correlate";

    @Bean
    public TopicExchange healthOsExchange() {
        return ExchangeBuilder.topicExchange(EXCHANGE).durable(true).build();
    }

    @Bean public Queue foodVisionQueue()   { return QueueBuilder.durable(FOOD_QUEUE).build(); }
    @Bean public Queue medicalOcrQueue()   { return QueueBuilder.durable(MEDICAL_QUEUE).build(); }
    @Bean public Queue ragInsightQueue()   { return QueueBuilder.durable(RAG_QUEUE).build(); }

    @Bean public Binding foodBinding(Queue foodVisionQueue, TopicExchange healthOsExchange) {
        return BindingBuilder.bind(foodVisionQueue).to(healthOsExchange).with(FOOD_KEY);
    }
    @Bean public Binding medicalBinding(Queue medicalOcrQueue, TopicExchange healthOsExchange) {
        return BindingBuilder.bind(medicalOcrQueue).to(healthOsExchange).with(MEDICAL_KEY);
    }
    @Bean public Binding ragBinding(Queue ragInsightQueue, TopicExchange healthOsExchange) {
        return BindingBuilder.bind(ragInsightQueue).to(healthOsExchange).with(RAG_KEY);
    }

    @Bean
    public Jackson2JsonMessageConverter messageConverter() {
        return new Jackson2JsonMessageConverter();
    }

    @Bean
    public RabbitTemplate rabbitTemplate(ConnectionFactory cf, Jackson2JsonMessageConverter converter) {
        RabbitTemplate template = new RabbitTemplate(cf);
        template.setMessageConverter(converter);
        return template;
    }
}
