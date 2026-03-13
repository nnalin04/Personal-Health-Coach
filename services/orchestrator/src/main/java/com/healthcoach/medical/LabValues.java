package com.healthcoach.medical;

import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "lab_values", indexes = {
        @Index(name = "idx_lab_values_report", columnList = "report_id")
})
public class LabValues {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "report_id", nullable = false)
    private MedicalReport report;

    @jakarta.persistence.Column(name = "vitamin_d")
    private Double vitaminD;

    @jakarta.persistence.Column(name = "tsh")
    private Double tsh;

    @jakarta.persistence.Column(name = "ldl")
    private Double ldl;

    @jakarta.persistence.Column(name = "hdl")
    private Double hdl;

    @jakarta.persistence.Column(name = "triglycerides")
    private Double triglycerides;

    @jakarta.persistence.Column(name = "hba1c")
    private Double hba1c;

    @jakarta.persistence.Column(name = "creatinine")
    private Double creatinine;

    @jakarta.persistence.Column(name = "hemoglobin")
    private Double hemoglobin;

    @jakarta.persistence.Column(name = "alt")
    private Double alt;

    @jakarta.persistence.Column(name = "ast")
    private Double ast;

    @jakarta.persistence.Column(name = "glucose")
    private Double glucose;

    @jakarta.persistence.Column(name = "testosterone")
    private Double testosterone;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public MedicalReport getReport() {
        return report;
    }

    public void setReport(MedicalReport report) {
        this.report = report;
    }

    public Double getVitaminD() {
        return vitaminD;
    }

    public void setVitaminD(Double vitaminD) {
        this.vitaminD = vitaminD;
    }

    public Double getTsh() {
        return tsh;
    }

    public void setTsh(Double tsh) {
        this.tsh = tsh;
    }

    public Double getLdl() {
        return ldl;
    }

    public void setLdl(Double ldl) {
        this.ldl = ldl;
    }

    public Double getHdl() {
        return hdl;
    }

    public void setHdl(Double hdl) {
        this.hdl = hdl;
    }

    public Double getTriglycerides() {
        return triglycerides;
    }

    public void setTriglycerides(Double triglycerides) {
        this.triglycerides = triglycerides;
    }

    public Double getHba1c() {
        return hba1c;
    }

    public void setHba1c(Double hba1c) {
        this.hba1c = hba1c;
    }

    public Double getCreatinine() {
        return creatinine;
    }

    public void setCreatinine(Double creatinine) {
        this.creatinine = creatinine;
    }

    public Double getHemoglobin() {
        return hemoglobin;
    }

    public void setHemoglobin(Double hemoglobin) {
        this.hemoglobin = hemoglobin;
    }

    public Double getAlt() {
        return alt;
    }

    public void setAlt(Double alt) {
        this.alt = alt;
    }

    public Double getAst() {
        return ast;
    }

    public void setAst(Double ast) {
        this.ast = ast;
    }

    public Double getGlucose() {
        return glucose;
    }

    public void setGlucose(Double glucose) {
        this.glucose = glucose;
    }

    public Double getTestosterone() {
        return testosterone;
    }

    public void setTestosterone(Double testosterone) {
        this.testosterone = testosterone;
    }
}
