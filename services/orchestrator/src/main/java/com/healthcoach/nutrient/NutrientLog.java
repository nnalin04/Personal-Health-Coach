package com.healthcoach.nutrient;

import com.healthcoach.user.User;
import jakarta.persistence.*;
import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "nutrient_logs", indexes = {
    @Index(name = "idx_nutrient_logs_user_date", columnList = "user_id,log_date")
})
public class NutrientLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "food_log_id")
    private Long foodLogId;

    @Column(name = "log_date", nullable = false)
    private LocalDate logDate;

    // Vitamins
    @Column(name = "vitamin_a_mcg") private Double vitaminAMcg;
    @Column(name = "vitamin_b1_mg") private Double vitaminB1Mg;
    @Column(name = "vitamin_b2_mg") private Double vitaminB2Mg;
    @Column(name = "vitamin_b3_mg") private Double vitaminB3Mg;
    @Column(name = "vitamin_b6_mg") private Double vitaminB6Mg;
    @Column(name = "vitamin_b9_mcg") private Double vitaminB9Mcg;
    @Column(name = "vitamin_b12_mcg") private Double vitaminB12Mcg;
    @Column(name = "vitamin_c_mg") private Double vitaminCMg;
    @Column(name = "vitamin_d_mcg") private Double vitaminDMcg;
    @Column(name = "vitamin_e_mg") private Double vitaminEMg;
    @Column(name = "vitamin_k_mcg") private Double vitaminKMcg;

    // Minerals
    @Column(name = "calcium_mg") private Double calciumMg;
    @Column(name = "iron_mg") private Double ironMg;
    @Column(name = "zinc_mg") private Double zincMg;
    @Column(name = "magnesium_mg") private Double magnesiumMg;
    @Column(name = "potassium_mg") private Double potassiumMg;
    @Column(name = "selenium_mcg") private Double seleniumMcg;
    @Column(name = "iodine_mcg") private Double iodineMcg;

    @Column(name = "food_description", columnDefinition = "TEXT")
    private String foodDescription;

    private Double confidence;

    @Column(name = "created_at")
    private Instant createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = Instant.now();
    }

    // Getters and setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }

    public Long getFoodLogId() { return foodLogId; }
    public void setFoodLogId(Long foodLogId) { this.foodLogId = foodLogId; }

    public LocalDate getLogDate() { return logDate; }
    public void setLogDate(LocalDate logDate) { this.logDate = logDate; }

    public Double getVitaminAMcg() { return vitaminAMcg; }
    public void setVitaminAMcg(Double v) { this.vitaminAMcg = v; }

    public Double getVitaminB1Mg() { return vitaminB1Mg; }
    public void setVitaminB1Mg(Double v) { this.vitaminB1Mg = v; }

    public Double getVitaminB2Mg() { return vitaminB2Mg; }
    public void setVitaminB2Mg(Double v) { this.vitaminB2Mg = v; }

    public Double getVitaminB3Mg() { return vitaminB3Mg; }
    public void setVitaminB3Mg(Double v) { this.vitaminB3Mg = v; }

    public Double getVitaminB6Mg() { return vitaminB6Mg; }
    public void setVitaminB6Mg(Double v) { this.vitaminB6Mg = v; }

    public Double getVitaminB9Mcg() { return vitaminB9Mcg; }
    public void setVitaminB9Mcg(Double v) { this.vitaminB9Mcg = v; }

    public Double getVitaminB12Mcg() { return vitaminB12Mcg; }
    public void setVitaminB12Mcg(Double v) { this.vitaminB12Mcg = v; }

    public Double getVitaminCMg() { return vitaminCMg; }
    public void setVitaminCMg(Double v) { this.vitaminCMg = v; }

    public Double getVitaminDMcg() { return vitaminDMcg; }
    public void setVitaminDMcg(Double v) { this.vitaminDMcg = v; }

    public Double getVitaminEMg() { return vitaminEMg; }
    public void setVitaminEMg(Double v) { this.vitaminEMg = v; }

    public Double getVitaminKMcg() { return vitaminKMcg; }
    public void setVitaminKMcg(Double v) { this.vitaminKMcg = v; }

    public Double getCalciumMg() { return calciumMg; }
    public void setCalciumMg(Double v) { this.calciumMg = v; }

    public Double getIronMg() { return ironMg; }
    public void setIronMg(Double v) { this.ironMg = v; }

    public Double getZincMg() { return zincMg; }
    public void setZincMg(Double v) { this.zincMg = v; }

    public Double getMagnesiumMg() { return magnesiumMg; }
    public void setMagnesiumMg(Double v) { this.magnesiumMg = v; }

    public Double getPotassiumMg() { return potassiumMg; }
    public void setPotassiumMg(Double v) { this.potassiumMg = v; }

    public Double getSeleniumMcg() { return seleniumMcg; }
    public void setSeleniumMcg(Double v) { this.seleniumMcg = v; }

    public Double getIodineMcg() { return iodineMcg; }
    public void setIodineMcg(Double v) { this.iodineMcg = v; }

    public String getFoodDescription() { return foodDescription; }
    public void setFoodDescription(String v) { this.foodDescription = v; }

    public Double getConfidence() { return confidence; }
    public void setConfidence(Double v) { this.confidence = v; }

    public Instant getCreatedAt() { return createdAt; }
}
