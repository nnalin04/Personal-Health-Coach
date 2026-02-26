package com.healthcoach.medical.dto;

import com.healthcoach.medical.LabValues;

public record LabValuesResponse(
        Long id,
        Double vitaminD,
        Double tsh,
        Double ldl,
        Double hdl,
        Double triglycerides,
        Double hba1c,
        Double creatinine,
        Double hemoglobin,
        Double alt,
        Double ast,
        Double glucose,
        Double testosterone
) {
    public static LabValuesResponse from(LabValues values) {
        return new LabValuesResponse(
                values.getId(),
                values.getVitaminD(),
                values.getTsh(),
                values.getLdl(),
                values.getHdl(),
                values.getTriglycerides(),
                values.getHba1c(),
                values.getCreatinine(),
                values.getHemoglobin(),
                values.getAlt(),
                values.getAst(),
                values.getGlucose(),
                values.getTestosterone()
        );
    }
}
