# Proyecto Final - R Studio
## Bancarizacion de los jefes de hogar en el Peru (ENAHO 2020)

**Autor:** Fabrizzio Alem Artica Rosales
**Universidad:** Universidad Nacional del Centro del Peru (UNCP) - Facultad de Economia
**Curso:** R Studio - Proyecto Final

**Repositorio:** *(https://github.com/fabrizzioalemartica-svg/Proyecto_Final_R)*

---

## 1. Contexto del conjunto de datos

- **Institucion que proporciona los datos:** Instituto Nacional de Estadistica e Informatica (INEI) del Peru, a traves de los microdatos de libre acceso de la **Encuesta Nacional de Hogares (ENAHO) 2020** (http://iinei.inei.gob.pe/microdatos/).
- **Objetivo/tematica del conjunto de datos:** La ENAHO es la principal encuesta de hogares del Peru y permite medir las condiciones de vida de la poblacion. El extracto utilizado en este proyecto (`enaho01-2020-.dta`) contiene informacion a nivel de **jefes de hogar** sobre su ubicacion geografica, sexo y **acceso a servicios financieros** (tenencia de cuenta de ahorro o cuenta sueldo), lo cual permite analizar el nivel de **inclusion financiera (bancarizacion)** de los hogares peruanos en un anio marcado por la pandemia del COVID-19 y la entrega de bonos estatales por medios bancarios.
- **Principales variables analizadas:**

| Variable original | Variable renombrada | Descripcion |
|---|---|---|
| `conglome`, `vivienda`, `hogar`, `codperso` | `conglomerado`, `vivienda_id`, `hogar_id`, `persona_id` | Identificadores muestrales |
| `ubigeo` | `ubigeo_cod` | Codigo de ubicacion geografica (distrito) |
| `dominio` | `dominio_geo` | Dominio geografico (8 categorias: Costa, Sierra, Selva, Lima Metropolitana) |
| `estrato` | `estrato_geo` / `area` | Estrato geografico, agrupado en Urbano / Rural |
| `p203` | `parentesco` | Relacion de parentesco con el jefe de hogar (en este extracto, todos los registros son jefes de hogar) |
| `p207` | `sexo` | Sexo del jefe de hogar (Hombre / Mujer) |
| `p558e1_1` | `tiene_cuenta` / `bancarizado` | Indicador de bancarizacion: 1 = tiene cuenta de ahorro o cuenta sueldo, 0 = no tiene |
| `fac500a` | `factor_exp` | Factor de expansion muestral (ponderador poblacional) |

La base contiene **34,490 jefes de hogar** encuestados a nivel nacional en el 2020.

---

## 2. Estructura del repositorio

```
Proyecto_Final/
│
├── data/
│   ├── enaho01-2020-.dta                    # Base de datos original (INEI - ENAHO 2020)
│   ├── peru_departamental.geojson           # Limites departamentales (para el mapa)
│   ├── tabla_dominio.csv                    # Bancarizacion por dominio
│   ├── tabla_sexo.csv                       # Bancarizacion por sexo
│   ├── tabla_area.csv                       # Bancarizacion por area
│   ├── tabla_brecha_urbano_rural.csv        # Brecha por dominio (Parte 2)
│   ├── tabla_comparacion_con_sin_lima.csv   # Comparacion con/sin Lima
│   └── tabla_macrorregiones.csv             # Brecha por macrorregion
│
├── figures/
│   ├── collage_graficos.png                     # Collage con los 4 graficos del EDA
│   ├── grafico1_dominio.png
│   ├── grafico2_sexo.png
│   ├── grafico3_area.png
│   ├── grafico4_muestra_dominio.png
│   ├── grafico_final_brecha_urbano_rural.png    # Grafico principal de la Parte 2
│   ├── grafico5_con_sin_lima.png                # Analisis excluyendo Lima
│   ├── grafico6_macrorregiones.png              # Analisis por macrorregiones
│   └── mapa_peru_brecha_bancarizacion.png       # Mapa del Peru
│
├── scripts/
│   ├── EDA.R                    # Parte 1: importacion, limpieza, EDA y graficos
│   └── 04_analisis_final.R      # Parte 2: analisis final, macrorregiones y mapa
│
└── README.md
```

---

## PARTE 1 - Analisis Exploratorio de Datos (EDA)

### Importacion y limpieza (`scripts/EDA.R`)

El script `EDA.R`:
1. Importa la base con `haven::read_dta()`.
2. Renombra las variables a nombres descriptivos.
3. Recodifica `dominio_geo` y `sexo` como factores con etiquetas legibles.
4. Crea la variable `area` (Urbano/Rural) a partir del estrato geografico.
5. Filtra los 14 registros con valores faltantes en la variable de bancarizacion (quedan 34,476 observaciones).
6. Selecciona las columnas relevantes para el analisis.

### Estadisticas descriptivas principales

| Indicador | Valor |
|---|---|
| Jefes de hogar analizados | 34,476 |
| Tasa de bancarizacion nacional (ponderada) | **44.0%** |
| Tasa de bancarizacion - Mujeres | 44.4% |
| Tasa de bancarizacion - Hombres | 43.8% |
| Tasa de bancarizacion - Urbano | 48.4% |
| Tasa de bancarizacion - Rural | 23.4% |
| Dominio con mayor bancarizacion | Lima Metropolitana (56.6%) |
| Dominio con menor bancarizacion | Sierra Norte (30.1%) |

### Graficos (ggplot2)

El collage (`figures/collage_graficos.png`) incluye 4 visualizaciones:

1. **Grafico 1:** Tasa de bancarizacion por dominio geografico.
2. **Grafico 2:** Tasa de bancarizacion por sexo del jefe de hogar.
3. **Grafico 3:** Tasa de bancarizacion por ambito (urbano/rural).
4. **Grafico 4:** Numero de jefes de hogar encuestados por dominio geografico (tamano de muestra).

Todos los graficos incluyen titulo, subtitulo, etiquetas de ejes, leyenda (cuando corresponde) y un tema personalizado (`theme_minimal` con ajustes propios).

![Collage de graficos](figures/collage_graficos.png)

---

## PARTE 2 - Analisis final

### 1. Pregunta de analisis

Durante el EDA se encontro un hallazgo inesperado: la **brecha de genero** en bancarizacion es minima (44.4% mujeres vs. 43.8% hombres), pero la **brecha por ambito geografico** es enorme (48.4% urbano vs. 23.4% rural, **25 puntos porcentuales** de diferencia). Esto llevo a formular la siguiente pregunta:

> **¿La brecha de bancarizacion entre el ambito urbano y el ambito rural se mantiene constante en todo el pais, o se acentua en determinados dominios geograficos (sierra, selva, costa)?**

### 2. Analisis (`scripts/04_analisis_final.R`)

Se calculo la tasa de bancarizacion cruzando **dominio geografico x area (urbano/rural)**, y se construyo un indicador de **brecha en puntos porcentuales** (tasa urbana - tasa rural) para cada dominio. Ademas, se aplico una **prueba chi-cuadrado** de independencia entre area y bancarizacion para verificar que la asociacion es estadisticamente significativa.

**Brecha urbano-rural por dominio geografico (de mayor a menor):**

| Dominio geografico | Urbano | Rural | Brecha (p.p.) |
|---|---|---|---|
| Sierra Norte | 45.7% | 18.8% | **26.9** |
| Selva | 42.9% | 21.1% | **21.8** |
| Sierra Sur | 38.9% | 21.6% | 17.3 |
| Sierra Centro | 40.5% | 25.4% | 15.1 |
| Costa Centro | 51.4% | 39.5% | 11.9 |
| Costa Sur | 48.3% | 37.0% | 11.3 |
| Costa Norte | 43.9% | 34.4% | 9.5 |
| Lima Metropolitana | 56.6% | -- (sin poblacion rural en la muestra) | -- |

Prueba de independencia (area vs. bancarizacion): **Chi-cuadrado = 1829.4, p-value < 0.001**, por lo que la diferencia observada es estadisticamente significativa y no se debe al azar muestral.

![Grafico final](figures/grafico_final_brecha_urbano_rural.png)

### 3. Conclusiones finales

1. En el 2020, solo **4 de cada 10 jefes de hogar** en el Peru contaba con una cuenta de ahorro o cuenta sueldo (tasa nacional de 44.0%).
2. El **sexo del jefe de hogar no explica** diferencias relevantes en el acceso a servicios financieros: la brecha entre hombres y mujeres es de menos de 1 punto porcentual.
3. La verdadera brecha es **geografica**: los jefes de hogar rurales tienen una probabilidad mucho menor de estar bancarizados que los urbanos (23.4% vs. 48.4%).
4. Esta brecha **no es homogenea en el territorio**: se dispara en los dominios de **Sierra Norte (26.9 p.p.)** y **Selva (21.8 p.p.)**, mientras que es comparativamente menor en los dominios de costa (9.5 a 11.9 p.p.). Lima Metropolitana, al ser un dominio casi enteramente urbano, no permite esta comparacion.
5. **Implicancia de politica publica:** los esfuerzos de inclusion financiera y bancarizacion (agentes bancarios, banca movil, billeteras digitales, corresponsales) deberian priorizarse en las zonas rurales de la sierra norte y la selva, donde la brecha de acceso respecto a sus pares urbanos es mas amplia.

---

---

## Modificaciones y analisis adicionales (recomendaciones del profesor)

### a) Fondo blanco en los graficos
Se fijo explicitamente `plot.background`, `panel.background` y `legend.background` en blanco (mas `bg = "white"` en cada `ggsave()`), ya que las zonas transparentes del PNG se veian negras en pantallas con modo oscuro y dificultaban leer los textos. Todos los graficos fueron regenerados.

### b) Analisis excluyendo Lima Metropolitana
Lima Metropolitana concentra ~30% de los jefes de hogar del pais y tiene la tasa de bancarizacion mas alta, por lo que puede estar "inflando" el promedio nacional. Se recalcularon los indicadores excluyendola:

| Escenario | Tasa nacional | Brecha urbano-rural |
|---|---|---|
| Con Lima Metropolitana | 44.0% | 25.0 p.p. |
| Sin Lima Metropolitana | **38.3%** | **20.0 p.p.** |

**Lectura:** al retirar Lima, la tasa nacional cae casi 6 puntos y la brecha urbano-rural se reduce (de 25 a 20 p.p.), lo que confirma que buena parte del nivel de bancarizacion del pais depende del peso de la capital, y que el "resto del Peru" enfrenta una brecha de acceso financiero considerable por si sola, incluso sin el efecto Lima.

![Con y sin Lima](figures/grafico5_con_sin_lima.png)

### c) Analisis por macrorregiones

Se agruparon los 24 departamentos + Callao en **5 macrorregiones** (Norte, Centro, Sur, Lima-Callao y Oriente), siguiendo el esquema de macrorregiones que se ha usado como referencia en las discusiones sobre reordenamiento territorial y regionalizacion en el Peru:

- **Norte:** Amazonas, Ancash, Cajamarca, La Libertad, Lambayeque, Piura, Tumbes
- **Centro:** Apurimac, Ayacucho, Huancavelica, Huanuco, Ica, Junin, Pasco
- **Sur:** Arequipa, Cusco, Madre de Dios, Moquegua, Puno, Tacna
- **Lima-Callao:** Lima, Callao
- **Oriente:** Loreto, San Martin, Ucayali

> **Nota:** no fue posible ubicar un documento unico y oficial titulado especificamente "propuesta de macrorregiones 2025" para verificar la lista exacta de tu profesor; se uso este esquema de 5 macrorregiones, ampliamente citado en la literatura de regionalizacion peruana. Si tu profesor te dio una lista distinta, solo edita el objeto `macro_map` al inicio del bloque 3-TER en `04_analisis_final.R` — el resto del script (tablas, graficos y el mapa) se recalcula automaticamente.

**Tasa de bancarizacion y brecha urbano-rural por macrorregion:**

| Macrorregion | Urbano | Rural | Brecha (p.p.) |
|---|---|---|---|
| Lima-Callao | 55.5% | 29.4% | 26.2 |
| Oriente | 44.9% | 21.3% | 23.6 |
| Norte | 45.1% | 24.1% | 21.0 |
| Centro | 42.3% | 23.0% | 19.4 |
| Sur | 41.1% | 23.3% | 17.8 |

![Macrorregiones](figures/grafico6_macrorregiones.png)

### d) Mapa del Peru

> **Aclaracion importante:** la base ENAHO utilizada en este proyecto **no contiene informacion de ingresos ni sueldos**, por lo que no es posible calcular una "brecha salarial". En su lugar, se mapeo la **brecha de bancarizacion urbano-rural** (en puntos porcentuales) por macrorregion, que es el indicador de inclusion financiera que si se puede calcular con esta base y que fue el hallazgo central del proyecto.

El mapa fue construido con el paquete `sf` y un archivo GeoJSON de los limites departamentales del Peru (fuente: [juaneladio/peru-geojson](https://github.com/juaneladio/peru-geojson)), coloreando cada departamento segun la brecha de la macrorregion a la que pertenece.

![Mapa de la brecha de bancarizacion](figures/mapa_peru_brecha_bancarizacion.png)

---

## Publicacion en redes sociales

Se publico en LinkedIn/X el hallazgo principal de la Parte 2 (grafico `grafico_final_brecha_urbano_rural.png`), acompanado de una breve explicacion del hallazgo. *(captura_de_la_publicación)*

---

## Como reproducir el analisis

```r
# Desde la carpeta Proyecto_Final/, en RStudio:
install.packages(c("haven", "dplyr", "tidyr", "forcats", "ggplot2", "scales",
                    "gridExtra", "sf"))

source("scripts/EDA.R")
source("scripts/04_analisis_final.R")
```

> El paquete `sf` (usado solo en `04_analisis_final.R` para el mapa) requiere las librerias del sistema GDAL/GEOS/PROJ. En Windows/Mac, `install.packages("sf")` normalmente las instala automaticamente junto con el binario. Si da error, revisa la guia oficial: https://r-spatial.github.io/sf/#installing
