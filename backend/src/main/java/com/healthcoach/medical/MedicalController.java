package com.healthcoach.medical;

import com.healthcoach.medical.dto.MedicalReportResponse;
import com.healthcoach.security.UserPrincipal;
import java.time.LocalDate;
import java.util.List;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/medical")
public class MedicalController {

    private final MedicalService medicalService;

    public MedicalController(MedicalService medicalService) {
        this.medicalService = medicalService;
    }

    @PostMapping(value = "/reports", consumes = {"multipart/form-data"})
    public MedicalReportResponse uploadReport(
            @AuthenticationPrincipal UserPrincipal principal,
            @RequestParam("file") MultipartFile file,
            @RequestParam("reportDate") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate reportDate
    ) {
        return medicalService.uploadAndParse(principal.getId(), file, reportDate);
    }

    @GetMapping("/reports")
    public List<MedicalReportResponse> listReports(@AuthenticationPrincipal UserPrincipal principal) {
        return medicalService.listReports(principal.getId());
    }
}
