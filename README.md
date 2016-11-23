![Logo Vélib'](velib_logo_212x100.png?raw=true)

<br>

L'objectif de ce projet est d'expérimenter certaines des possibilités du package R `leaflet` (disponible sur le [CRAN](https://cran.r-project.org/web/packages/leaflet/index.html)) en cartographiant les stations Vélib' parisiennes (et des villes alentours).

`Leaflet` est, à l'origine, une [bibliothèque javascript](http://leafletjs.com/) dont l'objectif est de permettre la réalisation de cartes interactives (un exemple d'utilisation parmi d'autres sur le site du [New York Times](http://www.nytimes.com/projects/elections/2013/nyc-primary/mayor/map.html)).

La [page d'aide](https://rstudio.github.io/leaflet/) (du package R) est une excellente ressource pour débuter.

## Les données

Les données utilisées sont accessibles librement sur [ParisData](http://opendata.paris.fr/), le site de la politique Open Data de la Ville de Paris.

#### Récupération des données (Python)

Le script Python ci-dessous permet de récupérer les données accessibles sur cette [page](http://opendata.paris.fr/explore/dataset/stations-velib-disponibilites-en-temps-reel/) toutes les 15 minutes tant que le programme tourne.

```Python
# -*- coding: utf-8 -*-

import requests
import time
import schedule

# The url of the data.
url = "http://opendata.paris.fr/explore/dataset/stations-velib-disponibilites-en-temps-reel/\
download/?format=csv&timezone=Europe/Berlin&use_labels_for_header=true"

def download_file():

    # Make the request.
    r = requests.get(url)

    # Get the current date and time.
    date_time = time.strftime("%Y-%m-%d_%Hh%M")
    
    # Save the csv file with the date and the time in the filename.
    with open("YOUR DIRECTORY/velib_" + date_time + ".csv", "wb") as code:
        code.write(r.content)

# Call the function every 15 minutes.
schedule.every(15).minutes.do(download_file)

while 1:
    schedule.run_pending()
    time.sleep(1)
```

Les fichiers sont enregistrés sous la forme : `velib_date_heure.csv`. Les données utilisées dans la suite ont été récupérées le mardi 26/01/2016 entre 9h00 et 21h00.

#### Importation et opérations élémentaires

L'importation des fichiers plats (csv) préalablement récupérés se fait sans difficultés particulières : on définit le répertoire où les fichiers sont enregistrés et l'on importe l'ensemble dans une liste appelée `velib`.

```R
setwd("./velib/data")
datasets <- list.files(pattern = "*.csv")

velib <- lapply(datasets, function (x) read.csv(x, sep = ";", 
                                                stringsAsFactors = FALSE))
```

Afin de faciliter les diverses opérations réalisées par la suite et la lecture des résultats, on peut donner des noms spécifiques aux différents *data frames* de la liste `velib`. Soit en l'occurrence, le nom des fichiers importés.

```R
names(velib) <- gsub(pattern = ".csv", replacement = "", datasets)
```

On vérifie alors que l'importation s'est correctement déroulée en affichant les premières lignes et les dimensions respectives des *data frames* de la liste.

```R
lapply(velib, head)
lapply(velib, dim)
```

Chaque *data frame* est constitué de 12 variables qui donnent notamment des informations sur le nom, l'addresse et le contrat des stations.

| number|                          name|                                           address| contract_name|
|------:|-----------------------------:|-------------------------------------------------:|-------------:|
|  13151|     13151 - GARE D'AUSTERLITZ|                   GARE D'AUSTERLITZ - 75013 PARIS|         Paris|
|  32602| 32602 - POULMARCH (LES LILAS)|            7 RUE JEAN POULMARCH - 93260 LES LILAS|         Paris|
|  19115|  19115 - PORTE DE LA VILLETTE| 1 AVENUE DE LA PORTE DE LA VILLETTE - 75019 PARIS|         Paris|
|  19027|             19027 - SERRURIER|         FACE 109 BOULEVARD SERURIER - 75019 PARIS|         Paris|

De plus, les données permettent d'avoir des informations sur l'état des stations : ouverte / fermée, sur la présence ou non d'une borne de paiement et de bonus ainsi que sur la position geographique respecticve de chacune.

| number| banking| bonus| status|                     position|
|------:|-------:|-----:|------:|----------------------------:|
|  13151|    True| False|   OPEN| 48.8405773029, 2.36612446186|
|  32602|    True|  True|   OPEN| 48.8794000532, 2.41616066183|
|  19115|    True| False|   OPEN| 48.8984900531, 2.38612000821|
|  19027|    True|  True|   OPEN| 48.8806060536, 2.39789629061|

Enfin, on peut également connaître le nombre de Vélib' disponibles, le nombre de points d'attache (libres et total) ainsi que l'heure de la derniere mise à jour pour chacune des stations.

| number| bike_stands| available_bike_stands| available_bikes|               last_update|
|------:|-----------:|---------------------:|---------------:|-------------------------:|
|  13151|          55|                    14|              37| 2016-01-20T12:41:51+01:00|
|  32602|          56|                    56|               0| 2016-01-20T12:42:14+01:00|
|  19115|          27|                     3|              24| 2016-01-20T12:42:02+01:00|
|  19027|          18|                    18|               0| 2016-01-20T12:42:06+01:00|

Dans la suite, l'on se concentre seulement sur les stations ouvertes qui peuvent être facilement sélectionnées comme ci-après.

```R
velib <- lapply(velib, function (x) filter(x, status == "OPEN"))
```

On peut de plus calculer pour chaque station le taux de disponibilité (le nombre de Vélib' divisé par le nombre total d'emplacements de la station considérée).

```R
velib <- lapply(velib, function (x) {
  mutate(x, availability = available_bikes / bike_stands * 100)
})
```

## Cartographie des stations Vélib'

#### Latitude et Longitude

La variable *position* donne, pour chacune des stations, la latitude et la longitude. Cependant, l'utilisation du package `leaflet` est d'autant plus aisée que ces informations sont accessibles de manière indépendante.

La fonction `lat_long()` ci-dessous permet ainsi de créer deux nouvelles colonnes *latitude* et *longitude* pour chacun des *data frames* de la liste `velib`.

```R
lat_long <- function (x) {
  x %>%
    mutate(latitude = gsub(pattern = ",.+", replacement = "", position),
           longitude = gsub(pattern = ".+,", replacement = "", position))
}

velib <- lapply(velib, lat_long)
```

#### Cartographie de l'ensemble des stations

La fonction `map_stations()` ci-après permet de représenter l'ensemble des stations Vélib' et de mettre en évidence quelques unes des possibilités du package `leaflet`.

```R
map_stations <- function(df, x) {
  
  # Extract the last 5 characters of the names of the data frames 
  # in the list df and replace the character "h" by ":"
  # (useful to display the hour for each map).
  
  time_legend <- names(df[x]) %>%
    substr(start = (nchar(.) + 1) - 5, nchar(.)) %>%
    gsub(pattern = "h", replacement = ":")
  
  leaflet(data = df[[x]]) %>% 
    setView(lng = 2.352427, lat = 48.856488, zoom = 12) %>%
    addProviderTiles("CartoDB.Positron") %>%
    addCircles(lng = ~ longitude, lat = ~ latitude,
               radius = ~ available_bikes * 5,
               color = ~ pal(availability), stroke = FALSE, fillOpacity = 0.8, 
               popup = ~ paste0(address, 
                                "<br>",  # HTML tag to add a line.
                                "Velib' disponibles : ",
                                as.character(available_bikes), 
                                " / ",
                                as.character(bike_stands))) %>%
    addLegend(position = "bottomleft", colors = NULL, labels = NULL,
              title = time_legend)
}

m <- lapply(names(velib), map_stations, df = velib)
m  # Show the maps.
```

* `leaflet()` est l'instruction de base permettant de créer une ou des cartes ; 
* `setView()` permet définir le niveau de zoom initial souhaité et de centrer la carte sur un point particulier ;
* `addProviderTiles()` permet d'ajouter un ou des [*layers*](http://leaflet-extras.github.io/leaflet-providers/preview/) ;
* `addCircles()` permet de positionner un marqueur sur la carte pour chaque station. Le rayon du marqueur étant fonction du nombre de Vélib' disponibles et la couleur du taux de disponibilité ;
* `addLegend()` permet d'ajouter une légende à la carte (en l'occurence simplement l'heure).

Le résultat obtenu est le suivant (cliquer sur la carte ou [ici](https://rawgit.com/thoera/velib/master/maps/all/velib_2016-01-26_09h00_all.html) pour accéder à la version html interactive) :

[![Map_1](/maps/all/velib_2016-01-26_09h00_all.png?raw=true)](https://rawgit.com/thoera/velib/master/maps/all/velib_2016-01-26_09h00_all.html)

Chaque station est représentée par un cercle. Plus le nombre de Vélib' disponibles dans une station est important et plus le rayon du cercle est important. La couleur des cercles est, quand à elle, définie par le taux de disponibilité des stations. 

Outre des cartes uniques comme celle présentée ci-dessus, on peut également essayer de mettre en évidence des schémas de fonctionnement dans l'utilisation des Vélib' en assemblant les données d'une journée entière (ou de tout autre période d'intérêt).

On peut, par exemple, voir s'il existe plusieurs types de stations distincts comme :
* des stations "Domicile" qui se videraient le matin et se rempliraient le soir ;
* des stations "Travail" qui, au contraire, se rempliraient le matin et se videraient le soir.

Plusieurs méthodes sont possibles pour réaliser cette opération d'assemblage :
* le package R `animation` ;
* l'utilisation d'outils comme ImageMagick ou son *fork* GraphicsMagick ;
* des outils d'édition et de retouche d'image (GIMP, Photoshop, etc.)
* autres...

L'assemblage suivant a, par exemple, été réalisé avec GIMP :

![GIF_1](https://github.com/thoera/velib/blob/master/maps/all/velib_2016-01-26_all.gif)

Globalement, on peut ainsi observer que les stations du centre de Paris semblent se remplir en milieu de journée et se vider progressivement en fin d'après-midi au détriment des stations des arrondissements plus extérieurs. 
Ceci pourrait confirmer l'hypothèse de stations "Domicile" et "Travail" puisque beaucoup d'entreprises possèdent en effet des locaux le long de la Seine.

#### Cartographie des stations en les regroupant par arrondissement

Le nombre de stations de Vélib' parisiennes étant important (plus de 1 200 stations uniques référencées dans les données), la quantité d'informations visuelles l'est également.

Pour contrer cette difficulté, une solution envisageable peut consister à regrouper les stations par arrondissement (ou ville si les stations se situent en dehors de Paris). 

Si ce regroupement induit nécessairement une perte d'information, il permet en revanche de limiter à une cinquantaine le nombre de stations représentées et facilite ainsi sensiblement l'exploration visuelle (le risque étant que le regroupement soit trop grossier et masque l'essentiel des schémas existants).

Dans cette optique, la première tâche consiste à isoler la ville et le code postal de l'adresse complète pour chacune des stations. Ceci peut être réalisé en utilisant une [expression régulière](https://en.wikipedia.org/wiki/Regular_expression) adéquate sur la variable *address*.

```R
zip_city <- function (x) {
  x %>%
    mutate(address_short = regmatches(address, gregexpr(pattern = "[0-9]{5,}.+",
                                                        address)) %>%
             unlist() %>%
             toupper() %>%
             gsub(pattern = "-", replacement = " "))
}

velib <- lapply(velib, zip_city)
```

La seconde étape consiste à créer un *data frame* de tous les arrondissements et villes où au moins une station Vélib' est présente.

```R
unique_arrond <- lapply(velib, function (x) {
  select(x, address_short) %>%
    unique()
})

unique_arrond <- Reduce(function(df1, df2) {
  merge(df1, df2, all = TRUE, by = "address_short")}, 
  unique_arrond)
```

On peut ensuite récupérer les coordonnées géographiques (latitude et longitude) de cette liste d'adresses avec la fonction `geocode()` du package `ggmap`.

```R
geocodes <- as.character(unique_arrond$address_short) %>%
  geocode()

unique_arrond <- cbind(unique_arrond, geocodes)
```
L'étape suivante consiste à regrouper les stations par arrondissement (ou ville si en dehors de Paris) et à déterminer, dans chaque cas, le nombre de vélos disponibles et le nombre d'emplacements (libres ou non) et ce pour l'ensemble des *data frames* de la liste `velib`.

```R
group_by_arrond <- function (x) {
  select(x, bike_stands, available_bike_stands, 
         available_bikes, address_short) %>%
    group_by(address_short) %>%
    summarise(bike_stands = sum(bike_stands), 
              available_bike_stands = sum(available_bike_stands),
              available_bikes = sum(available_bikes))  
}

velib_grouped_by_arrond <- lapply(velib, group_by_arrond)
```

Enfin, on peut fusionner le résultat obtenu avec les centres géographiques des arrondissements et villes récupérées précedemment.

```R
velib_grouped_by_arrond <- lapply(velib_grouped_by_arrond, function (x) {
  left_join(x, unique_arrond, by = "address_short")
})
```

La fonction `map_stations_grouped_by_arrond` ci-dessous permet alors d'obtenir les cartes souhaitées.

```R
map_stations_grouped_by_arrond <- function(df, x) {
  
  # Extract the last 5 characters of the names of the data frames 
  # in the list df and replace the character "h" by ":" 
  # (useful to display the hour for each map).
  
  time_legend <- names(df[x]) %>%
    substr(start = (nchar(.) + 1) - 5, nchar(.)) %>%
    gsub(pattern = "h", replacement = ":")
    
  leaflet(data = df[[x]]) %>%
    setView(lng = 2.352427, lat = 48.856488, zoom = 12) %>%
    addProviderTiles("CartoDB.Positron") %>%
    addCircles(lng = ~ lon, lat = ~ lat,
               radius = ~ available_bikes,
               color = ~ pal(availability), stroke = FALSE, fillOpacity = 0.8, 
               popup = ~ paste0(address_short, 
                                "<br>",  # HTML tag to add a line.
                                "Velib' disponibles : ",
                                as.character(available_bikes), 
                                " / ",
                                as.character(bike_stands))) %>%
    addLegend(position = "bottomleft", colors = NULL, labels = NULL,
              title = time_legend)
}

m <- lapply(names(velib_grouped_by_arrond), map_stations_grouped_by_arrond, 
            df = velib_grouped_by_arrond)
m  # Show the maps.
```

On peut, comme précédemment, réaliser une animation avec l'ensemble des cartes de la journée.

![GIF_2](https://github.com/thoera/velib/blob/master/maps/arrondissement/velib_2016-01-26_by_arrond.gif)

#### Créer une carte en utilisant une (ou des) icône(s) personnalisée(s)

Le package `leaflet` permet à l'utilisateur de définir simplement une ou des icônes (ou marqueurs).

En seulement quelques lignes de code, on peut ainsi réaliser des cartes personnalisées utilisant des marqueurs adaptés au sujet ou phénomène étudié.

Plusieurs fonction permettent de créer ces propres icônes : `makeIcon()`, `icons()` et `iconList()`. Ces trois fonctions ont leur utilité selon le nombre d'icônes à créer, le nombre de paramètres distincts, etc.

Dans le cas simple où un seul marqueur est créé, la fonction `makeIcon()` est simple d'utilisation puisqu'il suffit de spécifier le fichier à utiliser comme icône et les dimmensions de celle-ci.

```R
velib_icon <- makeIcon(iconUrl = "velib_icon_175x112.png", iconWidth = 80, 
                       iconHeight = 51)
```

La carte suivante représente ainsi les stations Vélib' du 1er arrondissement avec une icône particulièrement adaptée.

[![Map_2](/maps/velib_icon/stations_1_arron_velib_icon.png?raw=true)](https://rawgit.com/thoera/velib/master/maps/velib_icon/stations_1_arron_velib_icon.html)

#### Le nombre de Vélib' disponibles entre 10h00 et 17h00 comme indicateur ?

Une autre façon de mettre en évidence des schémas dans l'utilisation des Vélib' consiste à construire un indicateur permettant de quantifier le taux de disponibilité d'une station au cours de la journée.

Une possibilité consiste ainsi à calculer pour chaque station le rapport entre le nombre de Vélib' disponibles entre 10h00 et 17h00 et le nombre de Vélib' disponibles sur l'ensemble de la journée (plus précisément entre 9h00 et 21h00 dans ce cas particulier). 

Les stations dont la valeur de l'indicateur est relativement importante pourront être considérées comme des stations "Travail" (une part plus importante de vélos disponibles en journée) et les autres comme des stations "Domicile".

Cette opération est d'autant plus aisée que les données sont présentées sous la forme d'un unique *data frame* regroupant pour chacune des stations le nombre de Vélib' disponibles aux différentes heures de la journée. 

On commence ainsi par sélectionner les seules variables d'intérêt (l'identifiant des stations et le nombre de vélos disponibles) et par fusionner le tout dans un seul *data frame*.

```R
working_residential <- lapply(velib, function (x) {
  select(x, number, available_bikes)
})

working_residential <- Reduce(function(df1, df2) {
  merge(df1, df2, all = TRUE, by = "number")}, 
  working_residential)
```
On peut alors calculer les deux sommes nécessaires afin d'effectuer ensuite le ratio représentant notre indicateur. 

```R
available_bikes_10am_5pm <- as.character()

for (i in seq(10, 16)) {
  available_bikes_10am_5pm <- c(available_bikes_10am_5pm,
                                paste0("available_bikes_", i, ":00"))
  for (j in seq(15, 45, by = 15)) {
    available_bikes_10am_5pm <- c(available_bikes_10am_5pm,
                                  paste0("available_bikes_", i, ":", j))
  }
}

working_residential <- working_residential %>%
  mutate(available_bikes_10am_5pm = select(., 
                                           one_of(available_bikes_10am_5pm, 
                                                  "available_bikes_17:00")) %>% 
           rowSums(),
         available_bikes_9am_9pm = select(., contains("available_bikes")) %>% 
           rowSums())

# Compute the indicator as:
# "indicator" = "available_bikes_10am_5pm" / "available_bikes_9am_9pm"

working_residential <- working_residential %>%
  mutate(indicator = ifelse(available_bikes_9am_9pm != 0,
                            (available_bikes_10am_5pm / 
                               available_bikes_9am_9pm) %>%
                              round(2), 0))
```

Une fois le calcul de l'indicateur effectué, il reste à choisir un seuil permettant de classifier les stations dans une catégorie ou une autre. Le choix fait ici est simple mais hautement subjectif : les 25% des stations ayant une valeur de l'indicateur la plus élevée sont classés dans la catégorie "Travail" et les trois quarts restants dans la catégorie "Domicile".

```R
threshold <- quantile(working_residential$indicator,  probs = c(0.75))

working_residential <- working_residential %>%
  mutate(indicator_w_r = ifelse(indicator > threshold, "w", "r"))
```

On peut alors créer une carte où les stations du type "Travail" sont représentés en rouge et les stations du type "Domicile" en bleu/vert. 

[![Map_3](/maps/working_residential/working_residential.png?raw=true)](https://rawgit.com/thoera/velib/master/maps/working_residential/working_residential.html)

On remarque ainsi que les stations "Travail" sont, d'une part, plutôt au centre de Paris et, d'autre part, relativement groupées en certaines zones particulières.

Le graphique suivant présente pour les deux type de stations le taux de Vélib' disponibles sur l'ensemble de la période considérée. On y observe bien une chute brutale du taux de disponibilité des stations "Travail" en fin de journée (dès 17h00).  Le choix des boîtes à moustaches (ou *box plots*) permet d'appréhender la dispersion au sein de chaque catégorie.

![Boxplots](/maps/working_residential/boxplots.png)
