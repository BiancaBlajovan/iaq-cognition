# analyze_iaq_cognition.R
# Statistical analysis — IAQ & cognitive performance, 6 cohorts
# Matching: student registration number (matricol)
# Run: Session > Set Working Directory > to folder with merged_corrected_anonymised.csv
#      then press Source

library(tidyverse)
library(effectsize)
library(ggpubr)

# ── Load data ─────────────────────────────────────────────────────────────────
df <- read_csv("merged_corrected_anonymised.csv") %>%
  mutate(condition = factor(condition,
                            levels = c("dyson_on", "no_purifier"),
                            labels = c("Dyson ON", "No purifier")))

dir.create("figures", showWarnings = FALSE)

# ── Variable lists (exact column names from CSV) ──────────────────────────────
COG_VARS <- list(
  RT_simple_median        = "Simple RT (ms)",
  RT_choice_median        = "Choice RT (ms)",
  Stroop_interference_RT  = "Stroop Interference (ms)",
  Stroop_overall_accuracy = "Stroop Accuracy (%)",
  Nback_1_dprime_recalc   = "N-back d' 1-back",
  Nback_2_dprime_recalc   = "N-back d' 2-back",
  Nback_3_dprime_recalc   = "N-back d' 3-back",
  Nback_overall_accuracy  = "N-back Accuracy (%)"
)

IAQ_VARS <- list(
  iaq_CO2_ppm_mean   = "CO2 (ppm)",
  iaq_PM25_ugm3_mean = "PM2.5 (ug/m3)",
  iaq_PM1_ugm3_mean  = "PM1 (ug/m3)",
  iaq_NO2_ugm3_mean  = "NO2 (ug/m3)",
  iaq_t_celsius_mean = "Temperature (C)",
  iaq_rh_pct_mean    = "Humidity (%)"
)

COG_VARS <- COG_VARS[names(COG_VARS) %in% names(df)]
IAQ_VARS <- IAQ_VARS[names(IAQ_VARS) %in% names(df)]

cat("Found cognitive variables:", paste(names(COG_VARS), collapse=", "), "\n")
cat("Found IAQ variables:",       paste(names(IAQ_VARS), collapse=", "), "\n\n")

# ── 1. PAIRED T-TESTS (matched by matricol within each group) ─────────────────
cat("=== PAIRED T-TESTS ===\n")

paired_results <- map_dfr(names(COG_VARS), function(var) {
  label <- COG_VARS[[var]]

  wide <- df %>%
    filter(!is.na(.data[[var]]), !is.na(matricol)) %>%
    select(matricol, grup, condition, all_of(var)) %>%
    pivot_wider(names_from  = condition,
                values_from = all_of(var),
                values_fn   = first) %>%
    drop_na(`Dyson ON`, `No purifier`)

  if (nrow(wide) < 5) {
    cat(sprintf("  %-30s n=%d — not enough pairs, skipping\n", label, nrow(wide)))
    return(tibble(Variable=label, N_pairs=nrow(wide), Note="insufficient pairs"))
  }

  x <- wide[["Dyson ON"]]
  y <- wide[["No purifier"]]

  tt <- t.test(x, y, paired = TRUE)
  cd <- cohens_d(x, y, paired = TRUE)

  sig <- case_when(
    tt$p.value < 0.001 ~ "***",
    tt$p.value < 0.01  ~ "**",
    tt$p.value < 0.05  ~ "*",
    tt$p.value < 0.10  ~ ".",
    TRUE               ~ "ns"
  )

  cat(sprintf("  %-30s n=%d  Dyson=%.2f  NoPurif=%.2f  diff=%.2f (%.1f%%)  t=%.3f  p=%.4f %s  d=%.3f\n",
              label, nrow(wide), mean(x), mean(y),
              mean(x-y), mean(x-y)/mean(y)*100,
              tt$statistic, tt$p.value, sig, cd$Cohens_d))

  tibble(
    Variable     = label,
    N_pairs      = nrow(wide),
    Mean_Dyson   = round(mean(x), 3),
    SD_Dyson     = round(sd(x),   3),
    Mean_NoPurif = round(mean(y), 3),
    SD_NoPurif   = round(sd(y),   3),
    Diff         = round(mean(x - y), 3),
    Pct_change   = round(mean(x - y) / mean(y) * 100, 1),
    t_stat       = round(tt$statistic, 3),
    df           = round(tt$parameter, 1),
    p_value      = round(tt$p.value, 4),
    Cohens_d     = round(cd$Cohens_d, 3),
    Sig          = sig
  )
})

write_csv(paired_results, "table_paired_results.csv")
cat("\nSaved: table_paired_results.csv\n\n")

# ── 2. PEARSON CORRELATIONS ───────────────────────────────────────────────────
cat("=== PEARSON CORRELATIONS (significant only) ===\n")

cor_results <- map_dfr(names(IAQ_VARS), function(iaq) {
  map_dfr(names(COG_VARS), function(cog) {
    tmp <- df %>% select(all_of(c(iaq, cog))) %>% drop_na()
    if (nrow(tmp) < 15) return(NULL)
    ct <- cor.test(tmp[[iaq]], tmp[[cog]], method = "pearson")
    tibble(
      IAQ_var = IAQ_VARS[[iaq]],
      Cog_var = COG_VARS[[cog]],
      r       = round(ct$estimate, 3),
      p       = round(ct$p.value, 4),
      n       = nrow(tmp),
      Sig     = case_when(
        ct$p.value < 0.001 ~ "***",
        ct$p.value < 0.01  ~ "**",
        ct$p.value < 0.05  ~ "*",
        ct$p.value < 0.10  ~ ".",
        TRUE               ~ "ns")
    )
  })
})

sig_cors <- cor_results %>% filter(Sig != "ns") %>% arrange(p)
print(sig_cors, n = Inf)
write_csv(cor_results, "table_correlations.csv")
cat("\nSaved: table_correlations.csv\n\n")

# ── 3. FIGURE: Simple RT paired plot per group ────────────────────────────────
if ("RT_simple_median" %in% names(df)) {
  d_rt <- df %>%
    filter(!is.na(RT_simple_median), !is.na(matricol)) %>%
    select(matricol, grup, condition, RT_simple_median) %>%
    group_by(matricol) %>%
    filter(n_distinct(condition) == 2) %>%
    ungroup()

  p_rt <- ggpaired(d_rt,
    x = "condition", y = "RT_simple_median",
    id = "matricol",
    color = "condition",
    palette = c("#0F6E56", "#D85A30"),
    line.color = "gray70", line.size = 0.35,
    add = "jitter", add.params = list(size = 1.8, alpha = 0.7)) +
    facet_wrap(~grup, nrow = 2) +
    stat_compare_means(method = "t.test", paired = TRUE,
                       label = "p.format", label.x = 1.3, size = 3) +
    labs(title    = "Simple reaction time — Dyson ON vs No purifier",
         subtitle = "Each line = one student; p from paired t-test per group",
         x = NULL, y = "Median RT (ms)") +
    theme_pubr(base_size = 11) +
    theme(legend.position = "none",
          strip.background = element_rect(fill = "#f0f2f5"),
          strip.text = element_text(face = "bold", size = 9))

  ggsave("figures/fig_RT_paired.png", p_rt, width = 10, height = 7, dpi = 300)
  cat("Saved: figures/fig_RT_paired.pdf\n")
}

# ── 4. FIGURE: N-back d' 2-back paired plot ──────────────────────────────────
if ("Nback_2_dprime_recalc" %in% names(df)) {
  d_nb <- df %>%
    filter(!is.na(Nback_2_dprime_recalc), !is.na(matricol)) %>%
    select(matricol, grup, condition, Nback_2_dprime_recalc) %>%
    group_by(matricol) %>%
    filter(n_distinct(condition) == 2) %>%
    ungroup()

  p_nb <- ggpaired(d_nb,
    x = "condition", y = "Nback_2_dprime_recalc",
    id = "matricol",
    color = "condition",
    palette = c("#0F6E56", "#D85A30"),
    line.color = "gray70", line.size = 0.35,
    add = "jitter", add.params = list(size = 1.8, alpha = 0.7)) +
    facet_wrap(~grup, nrow = 2) +
    stat_compare_means(method = "t.test", paired = TRUE,
                       label = "p.format", label.x = 1.3, size = 3) +
    labs(title    = "Working memory d' (2-back) — Dyson ON vs No purifier",
         subtitle = "Each line = one student; higher d' = better memory",
         x = NULL, y = "d' sensitivity index") +
    theme_pubr(base_size = 11) +
    theme(legend.position = "none",
          strip.background = element_rect(fill = "#f0f2f5"),
          strip.text = element_text(face = "bold", size = 9))

  ggsave("figures/fig_Nback2_paired.png", p_nb, width = 10, height = 7, dpi = 300)
  cat("Saved: figures/fig_Nback2_paired.pdf\n")
}

# ── 5. FIGURE: Effect sizes summary ──────────────────────────────────────────
valid_results <- paired_results %>% filter(!is.na(Cohens_d))

if (nrow(valid_results) > 0) {
  p_cohen <- valid_results %>%
    mutate(direction = ifelse(Cohens_d < 0, "Dyson better", "No purifier better"),
           label     = paste0(round(Cohens_d, 2), " ", Sig)) %>%
    ggplot(aes(x = reorder(Variable, Cohens_d), y = Cohens_d, fill = direction)) +
    geom_col(width = 0.65) +
    geom_text(aes(label = label,
                  hjust = ifelse(Cohens_d >= 0, -0.1, 1.1)), size = 3.2) +
    geom_hline(yintercept = 0, linewidth = 0.6) +
    geom_hline(yintercept = c(-0.2, 0.2), linetype = "dashed",
               color = "gray60", linewidth = 0.4) +
    coord_flip(clip = "off") +
    scale_fill_manual(values = c("Dyson better"       = "#0F6E56",
                                 "No purifier better" = "#D85A30")) +
    labs(title    = "Effect sizes (Cohen's d) — all cognitive outcomes",
         subtitle = "Dashed lines: |d| = 0.2 (small effect threshold)",
         x = NULL, y = "Cohen's d", fill = NULL) +
    theme_pubr(base_size = 11) +
    theme(legend.position = "bottom",
          plot.margin = margin(5, 40, 5, 5))

  ggsave("figures/fig_effect_sizes.png", p_cohen, width = 8, height = 5, dpi = 300)
  cat("Saved: figures/fig_effect_sizes.pdf\n")
}

cat("\n=== DONE ===\n")
cat("Output files:\n")
cat("  table_paired_results.csv\n")
cat("  table_correlations.csv\n")
cat("  figures/fig_RT_paired.pdf\n")
cat("  figures/fig_Nback2_paired.pdf\n")
cat("  figures/fig_effect_sizes.pdf\n")

# ── 6. FIGURE: N-back d' 3-back paired plot ──────────────────────────────────
if ("Nback_3_dprime_recalc" %in% names(df)) {
  d_nb3 <- df %>%
    filter(!is.na(Nback_3_dprime_recalc), !is.na(matricol)) %>%
    select(matricol, grup, condition, Nback_3_dprime_recalc) %>%
    group_by(matricol) %>%
    filter(n_distinct(condition) == 2) %>%
    ungroup()

  p_nb3 <- ggpaired(d_nb3,
    x = "condition", y = "Nback_3_dprime_recalc",
    id = "matricol",
    color = "condition",
    palette = c("#0F6E56", "#D85A30"),
    line.color = "gray70", line.size = 0.35,
    add = "jitter", add.params = list(size = 1.8, alpha = 0.7)) +
    facet_wrap(~grup, nrow = 2) +
    stat_compare_means(method = "t.test", paired = TRUE,
                       label = "p.format", label.x = 1.3, size = 3) +
    labs(title    = "Working memory d' (3-back) — Dyson ON vs No purifier",
         subtitle = "Each line = one student · p = 0.011 overall (n = 27 matched pairs)",
         x = NULL, y = "d' sensitivity index") +
    theme_pubr(base_size = 11) +
    theme(legend.position = "none",
          strip.background = element_rect(fill = "#f0f2f5"),
          strip.text = element_text(face = "bold", size = 9))

  ggsave("figures/fig_Nback3_paired.png", p_nb3, width = 10, height = 7, dpi = 300)
  cat("Saved: figures/fig_Nback3_paired.pdf\n")
}

# ── 7. FIGURE: Choice RT paired plot ─────────────────────────────────────────
if ("RT_choice_median" %in% names(df)) {
  d_crt <- df %>%
    filter(!is.na(RT_choice_median), !is.na(matricol)) %>%
    select(matricol, grup, condition, RT_choice_median) %>%
    group_by(matricol) %>%
    filter(n_distinct(condition) == 2) %>%
    ungroup()

  p_crt <- ggpaired(d_crt,
    x = "condition", y = "RT_choice_median",
    id = "matricol",
    color = "condition",
    palette = c("#0F6E56", "#D85A30"),
    line.color = "gray70", line.size = 0.35,
    add = "jitter", add.params = list(size = 1.8, alpha = 0.7)) +
    facet_wrap(~grup, nrow = 2) +
    stat_compare_means(method = "t.test", paired = TRUE,
                       label = "p.format", label.x = 1.3, size = 3) +
    labs(title    = "Choice reaction time — Dyson ON vs No purifier",
         subtitle = "Each line = one student · p = 0.827 overall (ns)",
         x = NULL, y = "Median RT (ms)") +
    theme_pubr(base_size = 11) +
    theme(legend.position = "none",
          strip.background = element_rect(fill = "#f0f2f5"),
          strip.text = element_text(face = "bold", size = 9))

  ggsave("figures/fig_ChoiceRT_paired.png", p_crt, width = 10, height = 7, dpi = 300)
  cat("Saved: figures/fig_ChoiceRT_paired.pdf\n")
}

# ── 8. FIGURE: Stroop interference paired plot ────────────────────────────────
if ("Stroop_interference_RT" %in% names(df)) {
  d_str <- df %>%
    filter(!is.na(Stroop_interference_RT), !is.na(matricol)) %>%
    select(matricol, grup, condition, Stroop_interference_RT) %>%
    group_by(matricol) %>%
    filter(n_distinct(condition) == 2) %>%
    ungroup()

  p_str <- ggpaired(d_str,
    x = "condition", y = "Stroop_interference_RT",
    id = "matricol",
    color = "condition",
    palette = c("#0F6E56", "#D85A30"),
    line.color = "gray70", line.size = 0.35,
    add = "jitter", add.params = list(size = 1.8, alpha = 0.7)) +
    facet_wrap(~grup, nrow = 2) +
    stat_compare_means(method = "t.test", paired = TRUE,
                       label = "p.format", label.x = 1.3, size = 3) +
    labs(title    = "Stroop interference effect — Dyson ON vs No purifier",
         subtitle = "Each line = one student · p = 0.397 overall (ns) · lower = better inhibition",
         x = NULL, y = "Interference RT (ms)") +
    theme_pubr(base_size = 11) +
    theme(legend.position = "none",
          strip.background = element_rect(fill = "#f0f2f5"),
          strip.text = element_text(face = "bold", size = 9))

  ggsave("figures/fig_Stroop_interference_paired.png", p_str, width = 10, height = 7, dpi = 300)
  cat("Saved: figures/fig_Stroop_interference_paired.pdf\n")
}

# ── 9. FIGURE: Stroop accuracy paired plot ────────────────────────────────────
if ("Stroop_overall_accuracy" %in% names(df)) {
  d_sacc <- df %>%
    filter(!is.na(Stroop_overall_accuracy), !is.na(matricol)) %>%
    select(matricol, grup, condition, Stroop_overall_accuracy) %>%
    group_by(matricol) %>%
    filter(n_distinct(condition) == 2) %>%
    ungroup()

  p_sacc <- ggpaired(d_sacc,
    x = "condition", y = "Stroop_overall_accuracy",
    id = "matricol",
    color = "condition",
    palette = c("#0F6E56", "#D85A30"),
    line.color = "gray70", line.size = 0.35,
    add = "jitter", add.params = list(size = 1.8, alpha = 0.7)) +
    facet_wrap(~grup, nrow = 2) +
    stat_compare_means(method = "t.test", paired = TRUE,
                       label = "p.format", label.x = 1.3, size = 3) +
    labs(title    = "Stroop accuracy — Dyson ON vs No purifier",
         subtitle = "Each line = one student · p = 0.184 overall (ns) · higher = better",
         x = NULL, y = "Accuracy (%)") +
    theme_pubr(base_size = 11) +
    theme(legend.position = "none",
          strip.background = element_rect(fill = "#f0f2f5"),
          strip.text = element_text(face = "bold", size = 9))

  ggsave("figures/fig_Stroop_accuracy_paired.png", p_sacc, width = 10, height = 7, dpi = 300)
  cat("Saved: figures/fig_Stroop_accuracy_paired.pdf\n")
}

# ── 10. FIGURE: N-back d' 1-back paired plot ─────────────────────────────────
if ("Nback_1_dprime_recalc" %in% names(df)) {
  d_nb1 <- df %>%
    filter(!is.na(Nback_1_dprime_recalc), !is.na(matricol)) %>%
    select(matricol, grup, condition, Nback_1_dprime_recalc) %>%
    group_by(matricol) %>%
    filter(n_distinct(condition) == 2) %>%
    ungroup()

  p_nb1 <- ggpaired(d_nb1,
    x = "condition", y = "Nback_1_dprime_recalc",
    id = "matricol",
    color = "condition",
    palette = c("#0F6E56", "#D85A30"),
    line.color = "gray70", line.size = 0.35,
    add = "jitter", add.params = list(size = 1.8, alpha = 0.7)) +
    facet_wrap(~grup, nrow = 2) +
    stat_compare_means(method = "t.test", paired = TRUE,
                       label = "p.format", label.x = 1.3, size = 3) +
    labs(title    = "Working memory d' (1-back) — Dyson ON vs No purifier",
         subtitle = "Each line = one student · p = 0.109 overall (ns) · higher = better",
         x = NULL, y = "d' sensitivity index") +
    theme_pubr(base_size = 11) +
    theme(legend.position = "none",
          strip.background = element_rect(fill = "#f0f2f5"),
          strip.text = element_text(face = "bold", size = 9))

  ggsave("figures/fig_Nback1_paired.png", p_nb1, width = 10, height = 7, dpi = 300)
  cat("Saved: figures/fig_Nback1_paired.pdf\n")
}

cat("\nAll figures complete.\n")
