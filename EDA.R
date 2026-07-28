#############################################################################
# PROYECTO FINAL - R STUDIO
# Analisis Exploratorio de Datos (EDA)
# Tema: Bancarizacion (tenencia de cuenta de ahorro/sueldo) de los jefes
#       de hogar en el Peru - ENAHO 2020
# Autor: Fabrizzio Alem Artica Rosales
# Universidad Nacional del Centro del Peru - Facultad de Economia
#############################################################################

# 0. LIBRERIAS --------------------------------------------------------------
library(haven)      # importar archivos .dta (Stata)
library(dplyr)       # manipulacion de datos
library(tidyr)       # transformacion de datos
library(forcats)     # manejo de variables categoricas (factores)
library(ggplot2)      # visualizacion de datos
library(scales)       # formato de ejes (porcentajes)
library(gridExtra)    # collage de graficos

# 1. CONTEXTO DEL CONJUNTO DE DATOS -----------------------------------------
# Institucion : Instituto Nacional de Estadistica e Informatica (INEI - Peru)
# Fuente      : Encuesta Nacional de Hogares (ENAHO) 2020, Modulo 01/300
#               (Microdatos de libre acceso, disponibles en
#               http://iinei.inei.gob.pe/microdatos/)
# Objetivo    : La ENAHO recoge informacion sobre las condiciones de vida
#               de los hogares peruanos. Este extracto contiene, a nivel de
#               jefes de hogar, variables de ubicacion geografica y una
#               pregunta sobre inclusion financiera (tenencia de cuenta de
#               ahorro o cuenta sueldo), lo que permite estudiar la
#               bancarizacion de los hogares peruanos en el 2020, un anio
#               marcado por la pandemia del COVID-19 y la entrega de bonos
#               estatales por medios bancarios/digitales.
#
# Variables principales:
#   conglome    : numero de conglomerado (identificador muestral)
#   vivienda    : numero de seleccion de la vivienda
#   hogar       : numero secuencial del hogar
#   codperso    : numero de orden de la persona (=1, jefe de hogar)
#   ubigeo      : ubicacion geografica (codigo distrital)
#   dominio     : dominio geografico (8 categorias: costa, sierra, selva,
#                 Lima Metropolitana)
#   estrato     : estrato geografico segun tamanio poblacional
#                 (de urbano grande a rural)
#   p203        : relacion de parentesco con el jefe del hogar (=1 en
#                 este extracto, es decir, todos los registros son jefes
#                 de hogar)
#   p207        : sexo del jefe de hogar (1 = hombre, 2 = mujer)
#   p558e1_1    : indicador de bancarizacion. Toma valor 1 si la persona
#                 tiene cuenta de ahorro o cuenta sueldo, 0 si no
#   fac500a     : factor de expansion muestral (ponderador poblacional)

# 2. IMPORTACION DE DATOS ----------------------------------------------------
ruta_datos <- "data/enaho01-2020-.dta"
enaho <- read_dta(ruta_datos)

# Vistazo inicial
glimpse(enaho)
dim(enaho)

# 3. LIMPIEZA Y PREPARACION ---------------------------------------------------

# 3.1 Cambio de nombres de variables (nombres descriptivos) -----------------
enaho <- enaho %>%
  rename(
    conglomerado   = conglome,
    vivienda_id    = vivienda,
    hogar_id       = hogar,
    persona_id     = codperso,
    ubigeo_cod     = ubigeo,
    dominio_geo    = dominio,
    estrato_geo    = estrato,
    parentesco     = p203,
    sexo_cod       = p207,
    tiene_cuenta   = p558e1_1,
    factor_exp     = fac500a
  )

# 3.2 Creacion de nuevas variables (recodificacion con etiquetas) -----------
enaho <- enaho %>%
  mutate(
    dominio_geo = factor(
      dominio_geo,
      levels = 1:8,
      labels = c("Costa Norte", "Costa Centro", "Costa Sur",
                 "Sierra Norte", "Sierra Centro", "Sierra Sur",
                 "Selva", "Lima Metropolitana")
    ),
    sexo = factor(sexo_cod, levels = c(1, 2), labels = c("Hombre", "Mujer")),
    # Se agrupa el estrato geografico en una variable de area (urbano/rural)
    # segun la definicion del INEI: los estratos 1 al 6 son urbanos y los
    # estratos 7 y 8 corresponden a Area de Empadronamiento Rural (AER).
    area = if_else(estrato_geo %in% 1:6, "Urbano", "Rural"),
    area = factor(area, levels = c("Urbano", "Rural")),
    # Variable binaria de bancarizacion, ya lista para promedios (0/1)
    bancarizado = as.numeric(tiene_cuenta)
  )

# 3.3 Filtrado de observaciones ----------------------------------------------
# Se eliminan los registros sin informacion valida sobre bancarizacion
enaho_eda <- enaho %>%
  filter(!is.na(bancarizado))

cat("Observaciones originales:", nrow(enaho), "\n")
cat("Observaciones utilizadas en el EDA (sin missing en la variable clave):",
    nrow(enaho_eda), "\n")

# 3.4 Seleccion de columnas relevantes para el analisis ----------------------
enaho_eda <- enaho_eda %>%
  select(conglomerado, vivienda_id, hogar_id, ubigeo_cod,
         dominio_geo, estrato_geo, area, sexo, bancarizado, factor_exp)

# 4. ESTADISTICAS DESCRIPTIVAS -----------------------------------------------

# 4.1 Estructura general
summary(enaho_eda)

# 4.2 Tasa de bancarizacion general (ponderada por el factor de expansion)
tasa_general <- enaho_eda %>%
  summarise(
    n_jefes_hogar     = n(),
    tasa_bancarizacion = weighted.mean(bancarizado, w = factor_exp) * 100
  )
print(tasa_general)

# 4.3 Tasa de bancarizacion por sexo del jefe de hogar
tabla_sexo <- enaho_eda %>%
  group_by(sexo) %>%
  summarise(
    n = n(),
    tasa_bancarizacion = weighted.mean(bancarizado, w = factor_exp) * 100
  ) %>%
  arrange(desc(tasa_bancarizacion))
print(tabla_sexo)

# 4.4 Tasa de bancarizacion por dominio geografico
tabla_dominio <- enaho_eda %>%
  group_by(dominio_geo) %>%
  summarise(
    n = n(),
    tasa_bancarizacion = weighted.mean(bancarizado, w = factor_exp) * 100
  ) %>%
  arrange(desc(tasa_bancarizacion))
print(tabla_dominio)

# 4.5 Tasa de bancarizacion por area (urbano / rural)
tabla_area <- enaho_eda %>%
  group_by(area) %>%
  summarise(
    n = n(),
    tasa_bancarizacion = weighted.mean(bancarizado, w = factor_exp) * 100
  )
print(tabla_area)

# 5. VISUALIZACION DE DATOS (ggplot2) -----------------------------------------

# Tema comun para todos los graficos del proyecto
# NOTA: se fija explicitamente el fondo en blanco (plot.background y
# panel.background) porque, al exportar el PNG, algunas areas quedaban
# transparentes y se veian negras (o el texto no se distinguia) al
# visualizarse en pantallas con modo oscuro.
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

# --- Grafico 1: Tasa de bancarizacion por dominio geografico ---------------
g1 <- tabla_dominio %>%
  ggplot(aes(x = fct_reorder(dominio_geo, tasa_bancarizacion),
             y = tasa_bancarizacion, fill = tasa_bancarizacion)) +
  geom_col(show.legend = FALSE) +
  coord_flip() +
  scale_fill_gradient(low = "#a6cee3", high = "#1f78b4") +
  labs(
    title = "Bancarizacion de los jefes de hogar segun dominio geografico",
    subtitle = "Porcentaje con cuenta de ahorro o cuenta sueldo - ENAHO 2020",
    x = "Dominio geografico",
    y = "Tasa de bancarizacion (%)"
  ) +
  tema_proyecto

ggsave("figures/grafico1_dominio.png", g1, width = 8, height = 5, dpi = 150, bg = "white")

# --- Grafico 2: Tasa de bancarizacion por sexo ------------------------------
g2 <- tabla_sexo %>%
  ggplot(aes(x = sexo, y = tasa_bancarizacion, fill = sexo)) +
  geom_col(width = 0.5) +
  geom_text(aes(label = paste0(round(tasa_bancarizacion, 1), "%")),
            vjust = -0.5, fontface = "bold") +
  scale_fill_manual(values = c("Hombre" = "#4575b4", "Mujer" = "#d73027")) +
  labs(
    title = "Bancarizacion de los jefes de hogar segun sexo",
    subtitle = "Porcentaje con cuenta de ahorro o cuenta sueldo - ENAHO 2020",
    x = "Sexo del jefe de hogar",
    y = "Tasa de bancarizacion (%)",
    fill = "Sexo"
  ) +
  ylim(0, max(tabla_sexo$tasa_bancarizacion) * 1.2) +
  tema_proyecto

ggsave("figures/grafico2_sexo.png", g2, width = 6, height = 5, dpi = 150, bg = "white")

# --- Grafico 3: Tasa de bancarizacion por area (urbano/rural) ---------------
g3 <- tabla_area %>%
  ggplot(aes(x = area, y = tasa_bancarizacion, fill = area)) +
  geom_col(width = 0.5) +
  geom_text(aes(label = paste0(round(tasa_bancarizacion, 1), "%")),
            vjust = -0.5, fontface = "bold") +
  scale_fill_manual(values = c("Urbano" = "#1a9850", "Rural" = "#fc8d59")) +
  labs(
    title = "Bancarizacion de los jefes de hogar segun ambito",
    subtitle = "Porcentaje con cuenta de ahorro o cuenta sueldo - ENAHO 2020",
    x = "Ambito geografico",
    y = "Tasa de bancarizacion (%)",
    fill = "Ambito"
  ) +
  ylim(0, max(tabla_area$tasa_bancarizacion) * 1.2) +
  tema_proyecto

ggsave("figures/grafico3_area.png", g3, width = 6, height = 5, dpi = 150, bg = "white")

# --- Grafico 4: Distribucion de jefes de hogar por dominio geografico -------
g4 <- enaho_eda %>%
  count(dominio_geo) %>%
  ggplot(aes(x = fct_reorder(dominio_geo, n), y = n)) +
  geom_col(fill = "#756bb1") +
  coord_flip() +
  labs(
    title = "Numero de jefes de hogar encuestados por dominio geografico",
    subtitle = "Muestra ENAHO 2020 (sin ponderar)",
    x = "Dominio geografico",
    y = "Numero de observaciones"
  ) +
  tema_proyecto

ggsave("figures/grafico4_muestra_dominio.png", g4, width = 8, height = 5, dpi = 150, bg = "white")

# --- Collage de graficos (obligatorio para la entrega) ----------------------
collage <- arrangeGrob(g1, g2, g3, g4, ncol = 2)
ggsave("figures/collage_graficos.png", collage, width = 14, height = 10, dpi = 150, bg = "white")

# 6. GUARDAR TABLAS RESUMEN (para el README y el analisis final) ------------
write.csv(tabla_dominio, "data/tabla_dominio.csv", row.names = FALSE)
write.csv(tabla_sexo, "data/tabla_sexo.csv", row.names = FALSE)
write.csv(tabla_area, "data/tabla_area.csv", row.names = FALSE)

cat("\n--- EDA finalizado. Graficos guardados en la carpeta 'figures/' ---\n")
