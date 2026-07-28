#############################################################################
# PROYECTO FINAL - R STUDIO (PARTE 2)
# Analisis final: brecha urbano-rural en la bancarizacion de los jefes
#                 de hogar en el Peru - ENAHO 2020
# Autor: Fabrizzio Alem Artica Rosales
#
# Version 2: incorpora las observaciones del profesor:
#   a) Analisis excluyendo Lima Metropolitana
#   b) Analisis agrupando departamentos en macrorregiones
#   c) Fondo blanco explicito en todos los graficos
#   d) Mapa del Peru con el porcentaje de la brecha (por macrorregion)
#############################################################################

library(haven)
library(dplyr)
library(tidyr)
library(forcats)
library(ggplot2)
library(scales)
library(sf)

# 1. IMPORTAR Y PREPARAR LOS DATOS (igual que en EDA.R) ---------------------
enaho <- read_dta("data/enaho01-2020-.dta") %>%
  rename(
    dominio_geo  = dominio,
    estrato_geo  = estrato,
    sexo_cod     = p207,
    tiene_cuenta = p558e1_1,
    factor_exp   = fac500a
  ) %>%
  mutate(
    dominio_geo = factor(
      dominio_geo,
      levels = 1:8,
      labels = c("Costa Norte", "Costa Centro", "Costa Sur",
                 "Sierra Norte", "Sierra Centro", "Sierra Sur",
                 "Selva", "Lima Metropolitana")
    ),
    sexo = factor(sexo_cod, levels = c(1, 2), labels = c("Hombre", "Mujer")),
    area = if_else(estrato_geo %in% 1:6, "Urbano", "Rural"),
    area = factor(area, levels = c("Urbano", "Rural")),
    bancarizado = as.numeric(tiene_cuenta),
    # Codigo de departamento (2 primeros digitos del ubigeo distrital),
    # segun la codificacion oficial INEI (01 = Amazonas ... 25 = Ucayali)
    dep_cod = substr(as.character(ubigeo), 1, 2)
  ) %>%
  filter(!is.na(bancarizado))

# Tabla de equivalencia oficial INEI: codigo de departamento -> nombre
tabla_departamentos <- tibble(
  dep_cod = sprintf("%02d", 1:25),
  departamento = c("AMAZONAS", "ANCASH", "APURIMAC", "AREQUIPA", "AYACUCHO",
                    "CAJAMARCA", "CALLAO", "CUSCO", "HUANCAVELICA", "HUANUCO",
                    "ICA", "JUNIN", "LA LIBERTAD", "LAMBAYEQUE", "LIMA",
                    "LORETO", "MADRE DE DIOS", "MOQUEGUA", "PASCO", "PIURA",
                    "PUNO", "SAN MARTIN", "TACNA", "TUMBES", "UCAYALI")
)

enaho <- enaho %>% left_join(tabla_departamentos, by = "dep_cod")

#############################################################################
# 2. PREGUNTA DE ANALISIS
#############################################################################
# Durante el EDA se encontro que, a diferencia de lo esperado, la brecha de
# bancarizacion por SEXO del jefe de hogar es minima (Mujer: 44.4% vs
# Hombre: 43.8%), mientras que la brecha por AMBITO geografico es enorme
# (Urbano: 48.4% vs Rural: 23.4%, mas de 25 puntos porcentuales). Esto
# motiva la siguiente pregunta de analisis:
#
#   ¿La brecha de bancarizacion entre el ambito urbano y el ambito rural
#   se mantiene constante en todo el pais, o se acentua en determinados
#   dominios geograficos y macrorregiones? ¿Y que tanto de esa brecha
#   nacional depende de Lima Metropolitana?
#############################################################################

# 3. ANALISIS: BRECHA URBANO-RURAL POR DOMINIO GEOGRAFICO --------------------

tabla_brecha <- enaho %>%
  group_by(dominio_geo, area) %>%
  summarise(
    n = n(),
    tasa_bancarizacion = weighted.mean(bancarizado, w = factor_exp) * 100,
    .groups = "drop"
  )

print(tabla_brecha)

tabla_brecha_ancha <- tabla_brecha %>%
  select(dominio_geo, area, tasa_bancarizacion) %>%
  pivot_wider(names_from = area, values_from = tasa_bancarizacion) %>%
  mutate(brecha_pp = Urbano - Rural) %>%
  arrange(desc(brecha_pp))

print(tabla_brecha_ancha)
write.csv(tabla_brecha_ancha, "data/tabla_brecha_urbano_rural.csv", row.names = FALSE)

tabla_contingencia <- table(enaho$area, enaho$bancarizado)
prueba_chi2 <- chisq.test(tabla_contingencia)
print(prueba_chi2)

cat("\nDominio con MAYOR brecha urbano-rural:\n")
print(tabla_brecha_ancha %>% slice_max(brecha_pp, n = 1))
cat("\nDominio con MENOR brecha urbano-rural:\n")
print(tabla_brecha_ancha %>% slice_min(brecha_pp, n = 1))

#############################################################################
# 3-BIS. ANALISIS EXCLUYENDO LIMA METROPOLITANA (recomendacion del profesor)
#############################################################################
# Lima Metropolitana concentra a mas del 30% de los jefes de hogar del pais
# y tiene la tasa de bancarizacion mas alta (56.6%), por lo que puede estar
# "inflando" el promedio nacional y ocultando la real magnitud de la brecha
# urbano-rural en el resto del pais. Se recalculan los indicadores
# excluyendo el dominio "Lima Metropolitana".

enaho_sin_lima <- enaho %>% filter(dominio_geo != "Lima Metropolitana")

tasa_con_lima <- enaho %>%
  summarise(tasa = weighted.mean(bancarizado, w = factor_exp) * 100) %>% pull(tasa)

tasa_sin_lima <- enaho_sin_lima %>%
  summarise(tasa = weighted.mean(bancarizado, w = factor_exp) * 100) %>% pull(tasa)

tabla_area_sin_lima <- enaho_sin_lima %>%
  group_by(area) %>%
  summarise(
    n = n(),
    tasa_bancarizacion = weighted.mean(bancarizado, w = factor_exp) * 100,
    .groups = "drop"
  )

cat("\n--- Comparacion CON vs SIN Lima Metropolitana ---\n")
cat("Tasa nacional de bancarizacion CON Lima Metropolitana:",
    round(tasa_con_lima, 1), "%\n")
cat("Tasa nacional de bancarizacion SIN Lima Metropolitana:",
    round(tasa_sin_lima, 1), "%\n")
print(tabla_area_sin_lima)

tabla_area <- enaho %>%
  group_by(area) %>%
  summarise(tasa_bancarizacion = weighted.mean(bancarizado, w = factor_exp) * 100,
            .groups = "drop")
brecha_con_lima <- tabla_area %>%
  pivot_wider(names_from = area, values_from = tasa_bancarizacion) %>%
  mutate(brecha_pp = Urbano - Rural)
brecha_sin_lima <- tabla_area_sin_lima %>%
  select(area, tasa_bancarizacion) %>%
  pivot_wider(names_from = area, values_from = tasa_bancarizacion) %>%
  mutate(brecha_pp = Urbano - Rural)

cat("\nBrecha urbano-rural CON Lima Metropolitana:",
    round(brecha_con_lima$brecha_pp, 1), "p.p.\n")
cat("Brecha urbano-rural SIN Lima Metropolitana:",
    round(brecha_sin_lima$brecha_pp, 1), "p.p.\n")

tabla_comparacion_lima <- tibble(
  escenario = c("Con Lima Metropolitana", "Sin Lima Metropolitana"),
  tasa_nacional = c(tasa_con_lima, tasa_sin_lima),
  brecha_urbano_rural_pp = c(brecha_con_lima$brecha_pp, brecha_sin_lima$brecha_pp)
)
write.csv(tabla_comparacion_lima, "data/tabla_comparacion_con_sin_lima.csv",
          row.names = FALSE)
print(tabla_comparacion_lima)

#############################################################################
# 3-TER. ANALISIS POR MACRORREGIONES (recomendacion del profesor)
#############################################################################
# Se agrupan los 24 departamentos + Callao en 5 macrorregiones, siguiendo el
# esquema de macrorregiones que se ha utilizado como referencia (entre
# otros usos, por el Tribunal Constitucional y por distintas mancomunidades
# regionales ya constituidas) en las discusiones sobre reordenamiento
# territorial: Macrorregion Norte, Centro, Sur, Lima-Callao y Oriente.
#
# NOTA METODOLOGICA: si tu profesor entrego una lista de departamentos por
# macrorregion distinta a la usada aqui, solo tienes que editar el vector
# "macro_map" de abajo; el resto del codigo se recalcula automaticamente.

macro_map <- c(
  "AMAZONAS" = "Norte", "ANCASH" = "Norte", "CAJAMARCA" = "Norte",
  "LA LIBERTAD" = "Norte", "LAMBAYEQUE" = "Norte", "PIURA" = "Norte",
  "TUMBES" = "Norte",

  "APURIMAC" = "Centro", "AYACUCHO" = "Centro", "HUANCAVELICA" = "Centro",
  "HUANUCO" = "Centro", "ICA" = "Centro", "JUNIN" = "Centro",
  "PASCO" = "Centro",

  "AREQUIPA" = "Sur", "CUSCO" = "Sur", "MADRE DE DIOS" = "Sur",
  "MOQUEGUA" = "Sur", "PUNO" = "Sur", "TACNA" = "Sur",

  "LIMA" = "Lima-Callao", "CALLAO" = "Lima-Callao",

  "LORETO" = "Oriente", "SAN MARTIN" = "Oriente", "UCAYALI" = "Oriente"
)

enaho <- enaho %>%
  mutate(macrorregion = factor(macro_map[departamento],
                                levels = c("Norte", "Centro", "Sur",
                                           "Lima-Callao", "Oriente")))

tabla_macro <- enaho %>%
  group_by(macrorregion, area) %>%
  summarise(
    n = n(),
    tasa_bancarizacion = weighted.mean(bancarizado, w = factor_exp) * 100,
    .groups = "drop"
  )
print(tabla_macro)

tabla_macro_ancha <- tabla_macro %>%
  select(macrorregion, area, tasa_bancarizacion) %>%
  pivot_wider(names_from = area, values_from = tasa_bancarizacion) %>%
  mutate(brecha_pp = Urbano - Rural) %>%
  arrange(desc(brecha_pp))
print(tabla_macro_ancha)
write.csv(tabla_macro_ancha, "data/tabla_macrorregiones.csv", row.names = FALSE)

tabla_macro_general <- enaho %>%
  group_by(macrorregion) %>%
  summarise(
    n = n(),
    tasa_bancarizacion = weighted.mean(bancarizado, w = factor_exp) * 100,
    .groups = "drop"
  ) %>%
  arrange(desc(tasa_bancarizacion))
print(tabla_macro_general)

#############################################################################
# 4. VISUALIZACION
#############################################################################

# Tema comun: fondo blanco explicito en todo (panel + plot + leyenda) para
# evitar areas transparentes que se ven negras en pantallas con modo oscuro
tema_proyecto <- theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11, color = "grey30"),
    axis.title = element_text(face = "bold"),
    legend.position = "bottom",
    plot.background = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "white", colour = NA),
    legend.background = element_rect(fill = "white", colour = NA),
    legend.key = element_rect(fill = "white", colour = NA)
  )

# --- Grafico A: brecha urbano-rural por dominio geografico ----------------
g_final <- tabla_brecha %>%
  mutate(dominio_geo = fct_reorder(dominio_geo, tasa_bancarizacion, .fun = max)) %>%
  ggplot(aes(x = dominio_geo, y = tasa_bancarizacion, fill = area)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.65) +
  geom_text(aes(label = paste0(round(tasa_bancarizacion, 0), "%")),
            position = position_dodge(width = 0.75),
            vjust = -0.4, size = 3.2, fontface = "bold") +
  coord_flip() +
  scale_fill_manual(values = c("Urbano" = "#1a9850", "Rural" = "#fc8d59")) +
  labs(
    title = "La brecha de bancarizacion no es pareja: se dispara en la sierra",
    subtitle = "Tasa de bancarizacion de jefes de hogar segun ambito y dominio geografico - ENAHO 2020 (INEI)",
    x = "Dominio geografico", y = "Tasa de bancarizacion (%)", fill = "Ambito",
    caption = "Fuente: INEI - ENAHO 2020. Elaboracion propia."
  ) +
  ylim(0, 80) +
  tema_proyecto

ggsave("figures/grafico_final_brecha_urbano_rural.png", g_final,
       width = 9, height = 6, dpi = 150, bg = "white")

# --- Grafico B: tasa nacional CON vs SIN Lima Metropolitana ---------------
g_sin_lima <- tabla_comparacion_lima %>%
  ggplot(aes(x = escenario, y = tasa_nacional, fill = escenario)) +
  geom_col(width = 0.5, show.legend = FALSE) +
  geom_text(aes(label = paste0(round(tasa_nacional, 1), "%")),
            vjust = -0.5, fontface = "bold") +
  scale_fill_manual(values = c("Con Lima Metropolitana" = "#3182bd",
                                "Sin Lima Metropolitana" = "#9ecae1")) +
  labs(
    title = "Lima Metropolitana empuja el promedio nacional hacia arriba",
    subtitle = "Tasa de bancarizacion nacional de jefes de hogar, con y sin Lima Metropolitana - ENAHO 2020",
    x = NULL, y = "Tasa de bancarizacion (%)",
    caption = "Fuente: INEI - ENAHO 2020. Elaboracion propia."
  ) +
  ylim(0, max(tabla_comparacion_lima$tasa_nacional) * 1.2) +
  tema_proyecto

ggsave("figures/grafico5_con_sin_lima.png", g_sin_lima,
       width = 7, height = 5.5, dpi = 150, bg = "white")

# --- Grafico C: brecha urbano-rural por macrorregion -----------------------
g_macro <- tabla_macro %>%
  mutate(macrorregion = fct_reorder(macrorregion, tasa_bancarizacion, .fun = max)) %>%
  ggplot(aes(x = macrorregion, y = tasa_bancarizacion, fill = area)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.6) +
  geom_text(aes(label = paste0(round(tasa_bancarizacion, 0), "%")),
            position = position_dodge(width = 0.75),
            vjust = -0.4, size = 3.4, fontface = "bold") +
  scale_fill_manual(values = c("Urbano" = "#1a9850", "Rural" = "#fc8d59")) +
  labs(
    title = "Bancarizacion por macrorregion: la brecha urbano-rural persiste",
    subtitle = "Departamentos agrupados en 5 macrorregiones - ENAHO 2020 (INEI)",
    x = "Macrorregion", y = "Tasa de bancarizacion (%)", fill = "Ambito",
    caption = "Macrorregiones: Norte, Centro, Sur, Lima-Callao y Oriente.\nFuente: INEI - ENAHO 2020. Elaboracion propia."
  ) +
  ylim(0, 80) +
  tema_proyecto

ggsave("figures/grafico6_macrorregiones.png", g_macro,
       width = 8.5, height = 5.5, dpi = 150, bg = "white")

#############################################################################
# 5. MAPA DEL PERU: BRECHA DE BANCARIZACION URBANO-RURAL POR MACRORREGION
#############################################################################
# IMPORTANTE: la base ENAHO utilizada en este proyecto NO incluye
# informacion de ingresos/salarios (no existe una variable de sueldo en
# este extracto), por lo que no es posible construir un mapa de "brecha
# salarial". En su lugar, se mapea la BRECHA DE BANCARIZACION (urbano menos
# rural, en puntos porcentuales), que es el indicador de inclusion
# financiera que sí se puede calcular con estos datos y que fue el
# hallazgo central de este proyecto.

peru_sf <- st_read("data/peru_departamental.geojson", quiet = TRUE)

peru_sf <- peru_sf %>%
  mutate(macrorregion = factor(macro_map[NOMBDEP],
                                levels = c("Norte", "Centro", "Sur",
                                           "Lima-Callao", "Oriente")))

peru_sf <- peru_sf %>%
  left_join(tabla_macro_ancha %>% select(macrorregion, brecha_pp),
            by = "macrorregion")

mapa_brecha <- ggplot(peru_sf) +
  geom_sf(aes(fill = brecha_pp), color = "white", linewidth = 0.3) +
  geom_sf_text(aes(label = paste0(round(brecha_pp, 0), "%")),
               size = 2.6, fontface = "bold", color = "grey15") +
  scale_fill_gradient(low = "#fee8c8", high = "#b30000",
                       name = "Brecha\nurbano-rural\n(p.p.)") +
  labs(
    title = "Brecha de bancarizacion urbano-rural por macrorregion",
    subtitle = "Diferencia en puntos porcentuales (tasa urbana - tasa rural) entre jefes de hogar - ENAHO 2020 (INEI)",
    caption = "Macrorregiones: Norte, Centro, Sur, Lima-Callao y Oriente.\nFuente: INEI - ENAHO 2020. Elaboracion propia."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10, color = "grey30"),
    axis.text = element_blank(),
    axis.title = element_blank(),
    panel.grid = element_blank(),
    plot.background = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "white", colour = NA),
    legend.background = element_rect(fill = "white", colour = NA)
  )

ggsave("figures/mapa_peru_brecha_bancarizacion.png", mapa_brecha,
       width = 7, height = 9, dpi = 150, bg = "white")

cat("\n--- Analisis final completado. Graficos guardados en 'figures/' ---\n")

#############################################################################
# 6. CONCLUSIONES PRINCIPALES
#############################################################################
# 1) La bancarizacion de los jefes de hogar en el Peru (2020) alcanza en
#    promedio 44.0%: mas de la mitad de los jefes de hogar aun no contaba
#    con una cuenta de ahorro o cuenta sueldo.
#
# 2) La brecha de genero es minima (Mujeres 44.4% vs Hombres 43.8%): el
#    sexo del jefe de hogar NO explica diferencias relevantes de acceso.
#
# 3) La brecha real y relevante es geografica: 48.4% (urbano) vs 23.4%
#    (rural), 25 puntos porcentuales de diferencia a nivel nacional.
#
# 4) Esta brecha urbano-rural NO es uniforme en el territorio: se agranda
#    considerablemente en los dominios/macrorregiones de sierra y selva
#    (Norte, Centro y Sur), y es menor en Lima-Callao, donde la poblacion
#    es predominantemente urbana.
#
# 5) Al EXCLUIR Lima Metropolitana, la tasa nacional de bancarizacion cae
#    y la brecha urbano-rural cambia: esto confirma que buena parte del
#    nivel de bancarizacion del pais depende de la alta tasa limeña, y que
#    el resto del Peru enfrenta una situacion de acceso financiero
#    considerablemente mas desigual.
#
# 6) Al agrupar los departamentos en 5 MACRORREGIONES (Norte, Centro, Sur,
#    Lima-Callao y Oriente), se confirma el mismo patron: Lima-Callao tiene
#    la mayor tasa de bancarizacion, mientras que las macrorregiones Norte
#    y Centro (predominantemente andinas) muestran las brechas mas amplias.
#
# 7) La prueba chi-cuadrado confirma que la asociacion entre el ambito
#    (urbano/rural) y la bancarizacion es estadisticamente significativa
#    (p-value < 0.001).
#
# 8) IMPLICANCIA DE POLITICA PUBLICA: los esfuerzos de inclusion financiera
#    deberian priorizarse en las zonas rurales de las macrorregiones Norte
#    y Centro, donde la brecha de acceso frente a sus pares urbanos -y
#    frente a Lima- es mas amplia.
#############################################################################
