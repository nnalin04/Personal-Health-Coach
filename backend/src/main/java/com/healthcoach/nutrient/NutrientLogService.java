package com.healthcoach.nutrient;

import com.healthcoach.nutrient.dto.*;
import com.healthcoach.user.User;
import org.springframework.stereotype.Service;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class NutrientLogService {

    private final NutrientLogRepository repo;

    public NutrientLogService(NutrientLogRepository repo) {
        this.repo = repo;
    }

    public NutrientLog save(NutrientLog log) {
        return repo.save(log);
    }

    public NutrientSummaryDTO getDailySummary(User user, LocalDate date) {
        List<NutrientLog> logs = repo.findByUserIdAndLogDate(user.getId(), date);
        Map<String, Double> totals = sumNutrients(logs);
        Map<String, Double> rdaMap = buildRdaMap(user.getGender());
        Map<String, Double> pct = computePercent(totals, rdaMap);
        List<String> deficient = pct.entrySet().stream()
            .filter(e -> e.getValue() < 80.0)
            .map(Map.Entry::getKey)
            .collect(Collectors.toList());
        List<String> adequate = pct.entrySet().stream()
            .filter(e -> e.getValue() >= 80.0)
            .map(Map.Entry::getKey)
            .collect(Collectors.toList());
        return new NutrientSummaryDTO(date, totals, rdaMap, pct, deficient, adequate);
    }

    public WeeklyNutrientTrendDTO getWeeklyTrend(User user, LocalDate to) {
        LocalDate from = to.minusDays(6);
        List<NutrientLog> logs = repo.findForPeriod(user.getId(), from, to);
        Map<String, Double> rdaMap = buildRdaMap(user.getGender());

        // Group by date
        Map<LocalDate, List<NutrientLog>> byDate = logs.stream()
            .collect(Collectors.groupingBy(NutrientLog::getLogDate));

        List<DailyNutrientDTO> days = new ArrayList<>();
        Map<String, List<Double>> allDayPcts = new LinkedHashMap<>();

        for (LocalDate d = from; !d.isAfter(to); d = d.plusDays(1)) {
            List<NutrientLog> dayLogs = byDate.getOrDefault(d, List.of());
            Map<String, Double> intake = sumNutrients(dayLogs);
            Map<String, Double> pct = computePercent(intake, rdaMap);
            days.add(new DailyNutrientDTO(d, intake, pct));
            pct.forEach((k, v) -> allDayPcts.computeIfAbsent(k, x -> new ArrayList<>()).add(v));
        }

        Map<String, Double> weeklyAvg = sumNutrients(logs);
        weeklyAvg.replaceAll((k, v) -> v / 7.0);

        Map<String, Double> weeklyAvgPct = computePercent(weeklyAvg, rdaMap);

        List<String> chronic = allDayPcts.entrySet().stream()
            .filter(e -> e.getValue().stream().filter(p -> p < 80.0).count() >= 4)
            .map(Map.Entry::getKey)
            .collect(Collectors.toList());

        return new WeeklyNutrientTrendDTO(from, to, days, weeklyAvg, rdaMap, weeklyAvgPct, chronic);
    }

    private Map<String, Double> sumNutrients(List<NutrientLog> logs) {
        Map<String, Double> totals = new LinkedHashMap<>();
        for (String key : RdaConstants.RDA.keySet()) {
            double sum = 0.0;
            for (NutrientLog log : logs) {
                Double val = getNutrientValue(log, key);
                if (val != null) sum += val;
            }
            totals.put(key, sum);
        }
        return totals;
    }

    private Map<String, Double> buildRdaMap(String gender) {
        Map<String, Double> rdaMap = new LinkedHashMap<>();
        for (String key : RdaConstants.RDA.keySet()) {
            rdaMap.put(key, RdaConstants.getRda(key, gender));
        }
        return rdaMap;
    }

    private Map<String, Double> computePercent(Map<String, Double> intake, Map<String, Double> rda) {
        Map<String, Double> pct = new LinkedHashMap<>();
        for (String key : rda.keySet()) {
            double rdaVal = rda.getOrDefault(key, 0.0);
            double intakeVal = intake.getOrDefault(key, 0.0);
            pct.put(key, rdaVal > 0 ? (intakeVal / rdaVal) * 100.0 : 0.0);
        }
        return pct;
    }

    private Double getNutrientValue(NutrientLog log, String key) {
        return switch (key) {
            case "vitaminAMcg"   -> log.getVitaminAMcg();
            case "vitaminB1Mg"   -> log.getVitaminB1Mg();
            case "vitaminB2Mg"   -> log.getVitaminB2Mg();
            case "vitaminB3Mg"   -> log.getVitaminB3Mg();
            case "vitaminB6Mg"   -> log.getVitaminB6Mg();
            case "vitaminB9Mcg"  -> log.getVitaminB9Mcg();
            case "vitaminB12Mcg" -> log.getVitaminB12Mcg();
            case "vitaminCMg"    -> log.getVitaminCMg();
            case "vitaminDMcg"   -> log.getVitaminDMcg();
            case "vitaminEMg"    -> log.getVitaminEMg();
            case "vitaminKMcg"   -> log.getVitaminKMcg();
            case "calciumMg"     -> log.getCalciumMg();
            case "ironMg"        -> log.getIronMg();
            case "zincMg"        -> log.getZincMg();
            case "magnesiumMg"   -> log.getMagnesiumMg();
            case "potassiumMg"   -> log.getPotassiumMg();
            case "seleniumMcg"   -> log.getSeleniumMcg();
            case "iodineMcg"     -> log.getIodineMcg();
            default -> null;
        };
    }
}
