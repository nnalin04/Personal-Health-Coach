package com.healthcoach.medical;

import com.healthcoach.aiclient.AiServiceClient;
import com.healthcoach.aiclient.dto.ParseMedicalReportResponse;
import com.healthcoach.aiclient.dto.ParsedLabValues;
import com.healthcoach.common.BadRequestException;
import com.healthcoach.medical.dto.MedicalReportResponse;
import com.healthcoach.user.User;
import com.healthcoach.user.UserService;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.time.LocalDate;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class MedicalService {

    private final MedicalReportRepository medicalReportRepository;
    private final LabValuesRepository labValuesRepository;
    private final UserService userService;
    private final AiServiceClient aiServiceClient;
    private final String uploadDir;

    public MedicalService(
            MedicalReportRepository medicalReportRepository,
            LabValuesRepository labValuesRepository,
            UserService userService,
            AiServiceClient aiServiceClient,
            @Value("${app.upload-dir}") String uploadDir) {
        this.medicalReportRepository = medicalReportRepository;
        this.labValuesRepository = labValuesRepository;
        this.userService = userService;
        this.aiServiceClient = aiServiceClient;
        this.uploadDir = uploadDir;
    }

    private static final Set<String> ALLOWED_MIME_TYPES = Set.of(
            "application/pdf", "image/png", "image/jpeg", "image/webp");

    @Transactional
    public MedicalReportResponse uploadAndParse(Long userId, MultipartFile file, LocalDate reportDate) {
        if (file.isEmpty()) {
            throw new BadRequestException("Medical report file is empty");
        }
        String contentType = file.getContentType();
        if (contentType == null || !ALLOWED_MIME_TYPES.contains(contentType)) {
            throw new BadRequestException("Invalid file type. Allowed: PDF, PNG, JPEG, WebP");
        }

        User user = userService.getById(userId);
        String storedPath = saveFile(userId, file);

        MedicalReport report = new MedicalReport();
        report.setUser(user);
        report.setReportFilePath(storedPath);
        report.setReportDate(reportDate);
        MedicalReport savedReport = medicalReportRepository.save(report);

        String fileBase64 = encodeBase64(file);
        ParseMedicalReportResponse parsed = aiServiceClient.parseMedicalReport(file.getOriginalFilename(), fileBase64,
                null);

        LabValues labValues = new LabValues();
        labValues.setReport(savedReport);

        ParsedLabValues parsedLabValues = parsed.labValues();
        if (parsedLabValues != null) {
            labValues.setVitaminD(parsedLabValues.vitaminD());
            labValues.setTsh(parsedLabValues.tsh());
            labValues.setLdl(parsedLabValues.ldl());
            labValues.setHdl(parsedLabValues.hdl());
            labValues.setTriglycerides(parsedLabValues.triglycerides());
            labValues.setHba1c(parsedLabValues.hba1c());
            labValues.setCreatinine(parsedLabValues.creatinine());
            labValues.setHemoglobin(parsedLabValues.hemoglobin());
            labValues.setAlt(parsedLabValues.alt());
            labValues.setAst(parsedLabValues.ast());
            labValues.setGlucose(parsedLabValues.glucose());
            labValues.setTestosterone(parsedLabValues.testosterone());
        }

        LabValues savedLabValues = labValuesRepository.save(labValues);
        List<String> notes = parsed.extractionNotes() == null ? List.of() : parsed.extractionNotes();
        return MedicalReportResponse.from(savedReport, List.of(savedLabValues), notes);
    }

    public List<MedicalReportResponse> listReports(Long userId) {
        List<MedicalReport> reports = medicalReportRepository.findByUserIdOrderByReportDateDesc(userId);
        // Load all lab values in one query, then group in memory — avoids N+1
        Map<Long, List<LabValues>> labsByReport = labValuesRepository
                .findByReportUserIdOrderByReportReportDateAsc(userId)
                .stream()
                .collect(Collectors.groupingBy(l -> l.getReport().getId()));
        return reports.stream()
                .map(report -> MedicalReportResponse.from(
                        report,
                        labsByReport.getOrDefault(report.getId(), List.of()),
                        List.of()))
                .toList();
    }

    private String saveFile(Long userId, MultipartFile file) {
        try {
            String extension = getExtension(file.getOriginalFilename());
            Path userDir = Path.of(uploadDir, "medical", String.valueOf(userId));
            Files.createDirectories(userDir);
            String name = UUID.randomUUID() + extension;
            Path output = userDir.resolve(name);
            Files.write(output, file.getBytes(), StandardOpenOption.CREATE_NEW);
            return output.toString();
        } catch (IOException ex) {
            throw new BadRequestException("Unable to store medical report");
        }
    }

    private String getExtension(String filename) {
        if (filename == null || !filename.contains(".")) {
            return ".bin";
        }
        return filename.substring(filename.lastIndexOf('.'));
    }

    private String encodeBase64(MultipartFile file) {
        try {
            return Base64.getEncoder().encodeToString(file.getBytes());
        } catch (IOException ex) {
            throw new BadRequestException("Unable to read file for AI parser");
        }
    }

    @org.springframework.scheduling.annotation.Scheduled(cron = "0 0 0 * * *") // Every night at midnight
    public void cleanupOldReports() {
        LocalDate threshold = LocalDate.now().minusDays(365); // Keep for 1 year
        List<MedicalReport> oldReports = medicalReportRepository.findByReportDateBefore(threshold);

        for (MedicalReport report : oldReports) {
            try {
                Files.deleteIfExists(Path.of(report.getReportFilePath()));
                medicalReportRepository.delete(report);
            } catch (IOException e) {
                // Log error
            }
        }
    }
}
