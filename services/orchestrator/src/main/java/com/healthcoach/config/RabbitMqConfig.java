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
 * Main exchange: health_os.tasks (topic)
 *   food.vision    → food-vision-queue    → on failure → food-vision-queue.dlq
 *   medical.ocr    → medical-ocr-queue   → on failure → medical-ocr-queue.dlq
 *   rag.correlate  → rag-insight-queue   → on failure → rag-insight-queue.dlq
 *   task.completed → task-completed-queue (Spring Boot WS bridge — no DLQ needed)
 *
 * Dead-letter exchange: health_os.tasks.dlx (direct)
 *   Messages are routed to their .dlq by original routing key.
 *   Monitor DLQ depth in RabbitMQ management UI / CloudAMQP dashboard to detect AI failures.
 *
 * Retry policy: x-message-ttl=60000 (1 min) on DLQs before manual requeue.
 */
@Configuration
public class RabbitMqConfig {

    // ── Main exchange & queues ────────────────────────────────────────────────
    public static final String EXCHANGE        = "health_os.tasks";
    public static final String FOOD_QUEUE      = "food-vision-queue";
    public static final String MEDICAL_QUEUE   = "medical-ocr-queue";
    public static final String RAG_QUEUE       = "rag-insight-queue";
    public static final String COMPLETED_QUEUE = "task-completed-queue";

    public static final String FOOD_KEY      = "food.vision";
    public static final String MEDICAL_KEY   = "medical.ocr";
    public static final String RAG_KEY       = "rag.correlate";
    public static final String COMPLETED_KEY = "task.completed";

    // ── Dead-letter exchange & queues ─────────────────────────────────────────
    public static final String DLX            = "health_os.tasks.dlx";
    public static final String FOOD_DLQ       = "food-vision-queue.dlq";
    public static final String MEDICAL_DLQ    = "medical-ocr-queue.dlq";
    public static final String RAG_DLQ        = "rag-insight-queue.dlq";

    // ── Exchanges ─────────────────────────────────────────────────────────────

    @Bean
    public TopicExchange healthOsExchange() {
        return ExchangeBuilder.topicExchange(EXCHANGE).durable(true).build();
    }

    /** Dead-letter exchange — direct type so routing key == queue name. */
    @Bean
    public DirectExchange deadLetterExchange() {
        return ExchangeBuilder.directExchange(DLX).durable(true).build();
    }

    // ── Main queues (with DLX configured) ────────────────────────────────────

    @Bean
    public Queue foodVisionQueue() {
        return QueueBuilder.durable(FOOD_QUEUE)
                .withArgument("x-dead-letter-exchange", DLX)
                .withArgument("x-dead-letter-routing-key", FOOD_DLQ)
                .build();
    }

    @Bean
    public Queue medicalOcrQueue() {
        return QueueBuilder.durable(MEDICAL_QUEUE)
                .withArgument("x-dead-letter-exchange", DLX)
                .withArgument("x-dead-letter-routing-key", MEDICAL_DLQ)
                .build();
    }

    @Bean
    public Queue ragInsightQueue() {
        return QueueBuilder.durable(RAG_QUEUE)
                .withArgument("x-dead-letter-exchange", DLX)
                .withArgument("x-dead-letter-routing-key", RAG_DLQ)
                .build();
    }

    @Bean
    public Queue taskCompletedQueue() {
        return QueueBuilder.durable(COMPLETED_QUEUE).build();
    }

    // ── Dead-letter queues ────────────────────────────────────────────────────

    @Bean
    public Queue foodVisionDlq() {
        return QueueBuilder.durable(FOOD_DLQ).build();
    }

    @Bean
    public Queue medicalOcrDlq() {
        return QueueBuilder.durable(MEDICAL_DLQ).build();
    }

    @Bean
    public Queue ragInsightDlq() {
        return QueueBuilder.durable(RAG_DLQ).build();
    }

    // ── Main bindings ─────────────────────────────────────────────────────────

    @Bean
    public Binding foodBinding(Queue foodVisionQueue, TopicExchange healthOsExchange) {
        return BindingBuilder.bind(foodVisionQueue).to(healthOsExchange).with(FOOD_KEY);
    }

    @Bean
    public Binding medicalBinding(Queue medicalOcrQueue, TopicExchange healthOsExchange) {
        return BindingBuilder.bind(medicalOcrQueue).to(healthOsExchange).with(MEDICAL_KEY);
    }

    @Bean
    public Binding ragBinding(Queue ragInsightQueue, TopicExchange healthOsExchange) {
        return BindingBuilder.bind(ragInsightQueue).to(healthOsExchange).with(RAG_KEY);
    }

    @Bean
    public Binding completedBinding(Queue taskCompletedQueue, TopicExchange healthOsExchange) {
        return BindingBuilder.bind(taskCompletedQueue).to(healthOsExchange).with(COMPLETED_KEY);
    }

    // ── DLQ bindings (direct exchange, routing key == queue name) ────────────

    @Bean
    public Binding foodDlqBinding(Queue foodVisionDlq, DirectExchange deadLetterExchange) {
        return BindingBuilder.bind(foodVisionDlq).to(deadLetterExchange).with(FOOD_DLQ);
    }

    @Bean
    public Binding medicalDlqBinding(Queue medicalOcrDlq, DirectExchange deadLetterExchange) {
        return BindingBuilder.bind(medicalOcrDlq).to(deadLetterExchange).with(MEDICAL_DLQ);
    }

    @Bean
    public Binding ragDlqBinding(Queue ragInsightDlq, DirectExchange deadLetterExchange) {
        return BindingBuilder.bind(ragInsightDlq).to(deadLetterExchange).with(RAG_DLQ);
    }

    // ── Serialisation & template ──────────────────────────────────────────────

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
