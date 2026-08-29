library(shiny)
library(shinydashboard)
library(data.table)
library(dplyr)
library(shinyjs)
library(shinyWidgets)
library(DT)
library(latex2exp)
library(shinycssloaders)
library(plotly)
library(tidyverse)
library(htmlwidgets)
library(ggplot2)
library(RMySQL)
library(DBI)
library(gridExtra)
library(ggforce)
library(lubridate)
library(directlabels)
library(bigrquery)

source("helper_functions/general_functions.R")
source("helper_functions/hitter_functions.R")
source("helper_functions/pitcher_functions.R")

# If you want to clean a Trackman csv file for the app, 
# use the file clean_trackman_data.R in the data folder

# 2021 Fall CSV cleaned for app
Trackman <- fread("data/V3 Merged Files Through 4-3 CLEANED.csv")
Trackman_csv <- read.csv("data/V3 Merged Files Through 4-3 CLEANED.csv")

# NEW STARTS HERE

bq_auth(
  path = "Database Connecting/baseball-consulting-439523-1b0c04c432e7.json",
  scopes = c("https://www.googleapis.com/auth/bigquery",
             "https://www.googleapis.com/auth/cloud-platform"),
  cache = gargle::gargle_oauth_cache(),
  use_oob = TRUE,
  token = NULL
)
con <- dbConnect(bigrquery::bigquery(), project = "baseballdb", dataset = "trackman", billing = "baseball-consulting-439523")

pitcher_query <- DBI::dbSendQuery(con, "SELECT DISTINCT Pitcher FROM baseballdb.trackman ORDER BY Pitcher")
pitcher_list <- unlist(DBI::dbFetch(pitcher_query), use.names=FALSE)

batter_query <- DBI::dbSendQuery(con, "SELECT DISTINCT Batter FROM baseballdb.trackman ORDER BY Batter")
batter_list <- unlist(DBI::dbFetch(batter_query), use.names=FALSE)

pitchtype_query <- DBI::dbSendQuery(con, "SELECT DISTINCT TaggedPitchType FROM baseballdb.trackman ORDER BY TaggedPitchType;")
pitchtype_list <- unlist(DBI::dbFetch(pitchtype_query), use.names=FALSE)

minmaxdate_query <- DBI::dbSendQuery(con, "SELECT MIN(PARSE_DATE('%Y-%m-%d', Date)) AS earliest_date, MAX(PARSE_DATE('%Y-%m-%d', Date)) AS latest_date FROM baseballdb.trackman;")
minmaxdate_list <- unlist(DBI::dbFetch(minmaxdate_query), use.names=FALSE)
minmaxdate_list <- as.Date(minmaxdate_list, origin = "1970-01-01")

# NEW ENDS HERE

header <- dashboardHeader(
  title = "UCLA Baseball"
)

sidebar <- dashboardSidebar(
  tags$style(
    "#sidebarItemExpanded {
    overflow-y: auto;
    overflow-x: hidden;
    max-height: 90vh;
    }"
  ),
  sidebarMenu(
    id = "sidebarmenu",
    dateRangeInput(inputId = "daterange", label = "Date Range:",
                   start = min(minmaxdate_list), # NEW
                   end = max(minmaxdate_list), # NEW
                   #start = min(Trackman$Date),
                   #end = max(Trackman$Date),
                   format = "mm/dd/yyyy",
                   separator = "to"),
    menuItem("PITCHERS", tabName = "pitchers"),
    conditionalPanel(id = "pitcherfilters",
                     condition = "input.sidebarmenu === 'pitchers'",
                     title = "Filters:",
                     shinyjs::useShinyjs(),
                     icon = shiny::icon("search"),
                     pickerInput("pitcherSearch", "Pitcher Search:",
                                 choices = c("All", pitcher_list), # NEW
                                 #choices = c("All", levels(as.factor(Trackman$Pitcher[Trackman$PitcherTeam == "UCLA"]))),
                                 selected = "All",
                                 options = list(
                                   `live-search` = TRUE,
                                   size = 5
                                 )),
                     uiOutput("pitcherBatterOpponent"),
                     selectInput("bDexterity", #label = "Batter Handedness:",
                                 label = "Batter Side", # NEW
                                 choices = c("All", "Right", "Left"), # NEW
                                 #choices = c("All", levels(as.factor(Trackman$BatterSide[Trackman$BatterSide != "S"]))),
                                 selected = "All"),
                     selectInput("pitchTypeP", label = "Pitch Type:",
                                 choices = c("All", pitchtype_list), # NEW
                                 #choices = c("All", levels(as.factor(Trackman$TaggedPitchType[Trackman$TaggedPitchType != "Undefined" &
                                 #                                                             Trackman$TaggedPitchType != "Other"]))),
                                 selected = "All"),
                     selectInput("hitTypeP", label = "Hit Type:",
                                 choices = c("All", "GroundBall", "LineDrive", "Bunt", "FlyBall", "PopUp", "Popup", "Undefined"), # NEW
                                 #choices = c("All", levels(as.factor(Trackman$HitType[Trackman$HitType != "Undefined"]))),
                                 selected = "All"),
                     selectInput("pitchCallP", label = "Pitch Call:",
                                 choices = c("All", "StrikeCalled", "StrikeSwinging", "BallCalled", "InPlay", "FoulBall", "FoulBallFieldable", 
                                             "FoulBallNotFieldable", "HitByPitch", "BallInDirt", "BallIntentional", "Undefined"), # NEW
                                 #choices = c("All", levels(as.factor(Trackman$PitchCall[Trackman$PitchCall != "Undefined"]))),
                                 selected = "All"),
                     selectInput("pitchResultP", label = "Pitch Result:",
                                 choices = c("All", "Out", "Single", "Double", "Triple", "HomeRun", "Error", "FieldersChoice", "Sacrifice", 
                                             "StolenBase", "CaightStealing", "Undefined", "undefined "), # NEW
                                 #choices = c("All", levels(as.factor(Trackman$PlayResult[Trackman$PlayResult != "Undefined"]))),
                                 selected = "All"),
                     fluidRow(
                       column(width = 11, align = "center",
                              actionBttn("resetP", "Reset Filters", style = "bordered", size = "sm", color = "danger", icon = icon("redo"))))),
    menuItem("HITTERS", tabName = "hitters"),
    conditionalPanel(id = "hitterfilters",
                     condition = "input.sidebarmenu === 'hitters'",
                     title = "Filters:",
                     shinyjs::useShinyjs(),
                     icon = shiny::icon("search"),
                     pickerInput("hitterSearch", "Hitter Search:",
                                 choices = c("All", batter_list), # NEW
                                 #choices = (c("All", levels(as.factor(Trackman$Batter[Trackman$BatterTeam == "UCLA"])))),
                                 selected = "All",
                                 options = list(
                                   `live-search` = TRUE
                                 )),
                     uiOutput("hitterPitcherOpponent"),
                     selectInput("pDexterity", label = "Pitcher Handedness:",
                                 choices = c("All", levels(as.factor(Trackman$PitcherThrows[Trackman$PitcherThrows != "S"]))),
                                 selected = "All"),
                     selectInput("pitchTypeB", label = "Pitch Type:",
                                 choices = c("All", levels(as.factor(Trackman$TaggedPitchType[Trackman$TaggedPitchType != "Undefined" &
                                                                                                Trackman$TaggedPitchType != "Other"]))),
                                 selected = "All"),
                     selectInput("hitTypeB", label = "Hit Type:",
                                 choices = c("All", levels(as.factor(Trackman$HitType[Trackman$HitType != "Undefined"]))),
                                 selected = "All"),
                     selectInput("pitchCallB", label = "Pitch Call:", 
                                 choices = c("All", levels(as.factor(Trackman$PitchCall[Trackman$PitchCall != "Undefined"]))),
                                 selected = "All"),
                     selectInput("pitchResultB", label = "Pitch Result:",
                                 choices = c("All", levels(as.factor(Trackman$PlayResult[Trackman$PlayResult != "Undefined"]))),
                                 selected = "All"),
                     fluidRow(
                       column(width = 11, align = "center",
                              actionBttn("resetB", "Reset Filters", style = "bordered", size = "sm", color = "danger", icon = icon("redo")))))
#    menuItem("DEFENSE", tabName = "defense"),
#    conditionalPanel(condition = "input.sidebarmenu == 'defense'",
#                     id = "defensefilters",
#                     selectizeInput("playerSearch", "Player Search:",
#                                    choices = c("All", "ALL"),
#                                    selected = "All")),
#    menuItem("MODELS", tabName = "models"),
#    conditionalPanel(condition = "input.sidebarmenu == 'models'",
#                     id = "modelfilters",
#                     selectizeInput("modelSearch", "Model Selection:",
#                                    choices = c("1", "2", "3"),
#                                    selected = "All"))
  )
)

body <- dashboardBody(
  tabItems(
    tabItem(tabName = "pitchers",
            tabBox(id = "tabBoxP", width = 12,
                   tabPanel("Leaderboard",
                            box(
                              title = "Pitching Leaderboard (Averages)", width = 13, solidHeader = TRUE, status = "primary",
                              column(width = 12,
                                     DTOutput("pitcherleaderboard") %>% withSpinner(type = 7, size  = 0.5),
                                     style = "height:700px; overflow-y: scroll; overflow-x: scroll;"))),
                   tabPanel("Graphical",
                            fluidRow(
                              box(
                                title = "VELOCITY VS. SPIN RATE", width = 6, solidHeader = TRUE, status = "primary",
                                plotOutput("velospin", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px"),
                              box(
                                title = "RELEASE POSITION", width = 6, solidHeader = TRUE, status = "primary",
                                plotOutput("releaseposition", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px")),
                            fluidRow(
                              box(
                                title = "MOVEMENT (Catcher's Perspective):", width = 4, solidHeader = TRUE, status = "primary",
                                plotOutput("breaks", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px"),
                              box(
                                title = "PITCH LOCATION", width = 4, solidHeader = TRUE, status = "primary",
                                plotOutput("location", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px"),
                              box(
                                title = "SWINGS", width = 4, solidHeader = TRUE, status = "primary",
                                plotOutput("swingplotP", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px"))),
                   # Strike percentage by zone (R data)
                   #                   tabPanel("Spray Chart"),
                   tabPanel("Heat Map",
                            fluidRow(
                              column(width = 4,
                                     box(
                                       title = "Count", width = 12, solidHeader = TRUE, status = "primary", 
                                       plotOutput("countHeatMapP", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px")),
                              column(width = 4, 
                                     box(
                                       title = "Exit Velocity", width = 12, solidHeader = TRUE, status = "primary",
                                       plotOutput("evHeatMapP", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px")),
                              column(width = 4,
                                     box(
                                       title = "Launch Angle", width = 12, solidHeader = TRUE, status = "primary",
                                       plotOutput("laHeatMapP", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px"))),
                            fluidRow(
                              column(width = 4,
                                     box(
                                       title = "Balls In Play", width = 12, solidHeader = TRUE, status = "primary",
                                       plotOutput("bipHeatMapP", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px")),
                              column(width = 4,
                                     box(
                                       title = "Swing Rate (%)", width = 12, solidHeader = TRUE, status = "primary",
                                       plotOutput("swingrateHeatMapP", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px")),
                              column(width = 4, 
                                     box(
                                       title = "Whiff Rate (%)", width = 12, solidHeader = TRUE, status = "primary",
                                       plotOutput("whiffrateHeatMapP", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px")))),
                   tabPanel("Trends",
                            id = "pitcherTrends",
                            box(
                              title = "Game-by-Game Averages", width = 13, solidHeader = TRUE, status = "primary",
                              column(width = 12,
                                     tabsetPanel(id = "pitcherTrendTabs",
                                                 tabPanel("Velocity",
                                                          plotOutput("veloTrend", height = "680px") %>% withSpinner(type = 7, size  = 0.5),
                                                          style = "height:690px; overflow-x: scroll; vertical-align: center"),
                                                 tabPanel("Spin Rate", 
                                                          plotOutput("spinrateTrend", height = "680px") %>% withSpinner(type = 7, size  = 0.5 ),
                                                          style = "height:690px; overflow-x: scroll; vertical-align: center"),
                                                 tabPanel("Extension",
                                                          plotOutput("extensionTrend", height = "680px") %>% withSpinner(type = 7, size  = 0.5),
                                                          style = "height:690px; overflow-x: scroll; vertical-align: center"),
                                                 tabPanel("Horizontal Break",
                                                          plotOutput("horzbreakTrend", height = "680px") %>% withSpinner(type = 7, size  = 0.5),
                                                          style = "height:690px; overflow-x: scroll; vertical-align: center"),
                                                 tabPanel("Vertical Break",
                                                          plotOutput("vertbreakTrend", height = "680px") %>% withSpinner(type = 7, size  = 0.5),
                                                          style = "height:690px; overflow-x: scroll; vertical-align: center"),
                                                 tabPanel("Usage",
                                                          plotOutput("usageTrend", height = "680px") %>% withSpinner(type = 7, size = 0.5),
                                                          style = "height:690px; overflow-x: scroll; vertical-align: center"))))),
                   tabPanel("Zone Location",
                            fluidRow(column(width = 12,
                                            box(
                                              title = "Zone Location", width = 12, solidHeader = TRUE, status = "primary",
                                              plotOutput("zonelocation", height = "680px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px")))),
                   tabPanel("Advanced",
                            hr(),
                            box(title = "Advanced Stats", width = 13, solidHeader = TRUE, status = "primary",
                                column(width = 12,
                                       DTOutput("advancedstats") %>% withSpinner(type = 7, size  = 0.5),
                                       style = "height:200px; overflow-y: scroll; overflow-x: scroll;"))),
                   tabPanel("Comparison",
                            id = "pitcherComparison",
                            fluidRow(
                              column(width = 6,
                                     box(
                                       title = "Pitcher 1", width = 12, solidHeader = TRUE, status = "primary",
                                       pickerInput("pitcherInput1", "First Pitcher Search:",
                                                   choices = c("All", levels(as.factor(Trackman$Pitcher))),
                                                   selected = "All",
                                                   options = list(
                                                     `live-search` = TRUE,
                                                     size = 5)))),
                              column(width = 6, 
                                     box(
                                       title = "Pitcher 2", width = 12, solidHeader = TRUE, status = "primary",
                                       pickerInput("pitcherInput2", "Second Pitcher Search:",
                                                   choices = c("All", levels(as.factor(Trackman$Pitcher))),
                                                   selected = "All", 
                                                   options = list(
                                                     `live-search` = TRUE,
                                                     size = 5))))),
                            fluidRow(
                              box(
                                width = 12,
                                column(width = 12,
                                       tabsetPanel(type = "pills",
                                                   tabPanel("Metrics",
                                                            fluidRow(
                                                              column(width = 12,
                                                                     box(
                                                                       title = "Pitcher 1", width = 13, solidHeader = TRUE, status = "primary",
                                                                       DTOutput("metrics1", height = "250px") %>% withSpinner(type = 7, size  = 0.5), style = "height:260px"))),
                                                            fluidRow(
                                                              column(width = 12,
                                                                     box(
                                                                       title = "Pitcher 2", width = 13, solidHeader = TRUE, status = "primary",
                                                                       DTOutput("metrics2", height = "250px") %>% withSpinner(type = 7, size  = 0.5), style = "height:260px")))),
                                                   tabPanel("Graphics",
                                                            tabsetPanel(
                                                              tabPanel("Velo vs. Spin",
                                                                       fluidRow(
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 1", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("veloplot1", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")),
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 2", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("veloplot2", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")))),
                                                              tabPanel("Release Position",
                                                                       fluidRow(
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 1", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("release1", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")),
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 2", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("release2", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")))),
                                                              tabPanel("Movement",
                                                                       fluidRow(
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 1", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("movement1", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")),
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 2", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("movement2", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")))),
                                                              tabPanel("Pitch Location",
                                                                       fluidRow(
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 1", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("location1", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")),
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 2", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("location2", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")))),
                                                              tabPanel("Swings",
                                                                       fluidRow(
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 1", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("swings1", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")),
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 2", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("swings2", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")))))),
                                                   tabPanel("Heat Maps",
                                                            tabsetPanel(
                                                              tabPanel("Count",
                                                                       fluidRow(
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 1", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("count1", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")),
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 2", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("count2", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")))),
                                                              tabPanel("Balls In Play",
                                                                       fluidRow(
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 1", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("bip1", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")),
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 2", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("bip2", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")))),
                                                              tabPanel("Exit Velocity",
                                                                       fluidRow(
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 1", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("exitvelo1", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")),
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 2", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("exitvelo2", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")))),
                                                              tabPanel("Launch Angle",
                                                                       fluidRow(
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 1", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("launchangle1", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")),
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 2", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("launchangle2", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")))),
                                                              tabPanel("Swing Percentage",
                                                                       fluidRow(
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 1", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("swingperc1", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")),
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 2", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("swingperc2", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")))),
                                                              tabPanel("Whiff Percentage",
                                                                       fluidRow(
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 1", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("whiffperc1", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")),
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 2", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("whiffperc2", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")))))),
                                                   tabPanel("Trends",
                                                            tabsetPanel(
                                                              tabPanel("Velocity",
                                                                       fluidRow(
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 1", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("velotrend1", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")),
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 2", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("velotrend2", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")))),
                                                              tabPanel("Spin Rate",
                                                                       fluidRow(
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 1", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("spintrend1", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")),
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 2", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("spintrend2", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")))),
                                                              tabPanel("Extension",
                                                                       fluidRow(
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 1", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("extension1", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")),
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 2", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("extension2", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")))),
                                                              tabPanel("Horizontal Break",
                                                                       fluidRow(
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 1", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("horzbreak1", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")),
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 2", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("horzbreak2", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")))),
                                                              tabPanel("Vertical Break",
                                                                       fluidRow(
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 1", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("vertbreak1", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")),
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 2", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("vertbreak2", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")))),
                                                              tabPanel("Usage",
                                                                       fluidRow(
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 1", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("usage1", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px")),
                                                                         column(width = 6,
                                                                                box(
                                                                                  title = "Pitcher 2", width = 12, solidHeader = TRUE, status = "primary",
                                                                                  plotOutput("usage2", height = "460px") %>% withSpinner(type = 7, size = 0.5), style = "height:470px"))))))))))))),
    tabItem(tabName = "hitters",
            tabBox(id = "tabBoxH", width = 12,
                   tabPanel("Leaderboard",
                            box(
                              title = "Hitting Leaderboard (Averages)", width = 13, solidHeader = TRUE, status = "primary",
                              column(width = 12,
                                     DTOutput("hitterleaderboard") %>% withSpinner(type = 7, size  = 0.5),
                                     style = "height:700px; overflow-y: scroll; overflow-x: scroll;"))),
                   tabPanel("Batted Balls",
                            fluidRow(
                              box(
                                title = "EXIT VELO VS. LAUNCH ANGLE", width = 6, solidHeader = TRUE, status = "primary",
                                plotOutput("evlaPlot", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px"),
                              # box(
                              #   title = "SPRAY CHART (IN-PLAY)", width = 4, solidHeader = TRUE, status = "primary",
                              #   plotOutput("evlaPlot2", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px"),
                              box(
                                title = "SPRAY CHART", width = 6, solidHeader = TRUE, status = "primary",
                                plotOutput("evlaPlot3", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px")),
                            fluidRow(
                              box(
                                title = "CONTOUR PLOT", width = 4, solidHeader = TRUE, status = "primary",
                                plotOutput("contourplotB", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px"),
                              box(
                                title = "RADIAL CHART", width = 4, solidHeader = TRUE, status = "primary",
                                  plotOutput("radialPlot", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px"),
                              box(
                                title = "SWINGS", width = 4, solidHeader = TRUE, status = "primary",
                                plotOutput("swingplotB", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px"))),
                   tabPanel("Heat Map",
                            fluidRow(
                              column(width = 4,
                                     box(
                                       title = "Count", width = 12, solidHeader = TRUE, status = "primary", 
                                       plotOutput("countHeatMapB", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px")),
                              column(width = 4, 
                                     box(
                                       title = "Exit Velocity", width = 12, solidHeader = TRUE, status = "primary",
                                       plotOutput("evHeatMapB", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px")),
                              column(width = 4,
                                     box(
                                       title = "Launch Angle", width = 12, solidHeader = TRUE, status = "primary",
                                       plotOutput("laHeatMapB", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px"))),
                            fluidRow(
                              column(width = 4,
                                     box(
                                       title = "Balls In Play", width = 12, solidHeader = TRUE, status = "primary",
                                       plotOutput("bipHeatMapB", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px")),
                              column(width = 4,
                                     box(
                                       title = "Swing Rate (%)", width = 12, solidHeader = TRUE, status = "primary",
                                       plotOutput("swingrateHeatMapB", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px")),
                              column(width = 4, 
                                     box(
                                       title = "Whiff Rate (%)", width = 12, solidHeader = TRUE, status = "primary",
                                       plotOutput("whiffrateHeatMapB", height = "340px") %>% withSpinner(type = 7, size  = 0.5), style = "height:350px")))),
                   tabPanel("Advanced Metrics",
                            fluidRow(
                              box(
                                width = 12,
                                column(width = 12,
                                       tabsetPanel(type = "pills",
                                                   tabPanel("Advanced Statistics",
                                                            hr(),
                                                            box(title = "wOBA & xwOBA", width = 13, solidHeader = TRUE, status = "primary",
                                                                column(width = 12,
                                                                        DTOutput("wOBAtable") %>% withSpinner(type = 7, size  = 0.5),
                                                                        style = "height:200px; overflow-y: scroll; overflow-x: scroll;")),
                                                            hr(),
                                                            box(
                                                              title = "Batting Statistics", width = 13, solidHeader = TRUE, status = "primary",
                                                              fluidRow(
                                                                column(width = 12,
                                                                       DTOutput("statcastStats"))),
                                                              hr(),
                                                              fluidRow(
                                                                column(width = 12, 
                                                                       DTOutput("bypitchstatcastStats")))),
                                                            hr(),
                                                            box(
                                                              title = "OPS Chart", width = 13, solidHeader = TRUE, status = "primary",
                                                              fluidRow(
                                                                column(width = 12,
                                                                       plotOutput("opsChart"))))),
                                                   tabPanel("Pitch Tracking"),
                                                   tabPanel("Plate Discipline", 
                                                            box(
                                                              title = "Swing Decision", width = 12, solidHeader = TRUE, status = "primary",
                                                              plotOutput("swingdecision") %>% withSpinner(type = 7, size  = 0.5))),
                                                   tabPanel("Breakdowns",
                                                            box(title = "Histograms", width = 13, solidHeader = TRUE, status = "primary",
                                                                selectInput("histPlot", "Plot Output:", choices = c("Exit Velocity", "Launch Angle"),
                                                                            selected = "Exit Velocity"),
                                                                hr(),
                                                                plotOutput("histogram"))),
                                                   tabPanel("Zones"))))))))
  )
)


ui <- dashboardPage(
  header,
  sidebar,
  body
)


server <- function(input, output) {
  
  minDateInput <- reactive(input$daterange[1])
  maxDateInput <- reactive(input$daterange[2])
  
  # Reactive Pitcher Inputs:
  pitcherInput <- reactive(input$pitcherSearch)
  pitcherBatterOpponentInput <- reactive(input$pitcherBatterOpponent)
  bDexterityInput <- reactive(input$bDexterity)
  pitchTypeInputP <- reactive(input$pitchTypeP)
  hitTypeInputP <- reactive(input$hitTypeP)
  pitchCallInputP <- reactive(input$pitchCallP)
  pitchResultInputP <- reactive(input$pitchResultP)
  
  # New Code
  PitcherData <- reactive({
    
    DF <- Trackman %>% filter(TaggedPitchType != "Undefined",
                             TaggedPitchType != "Other",
                             (Date >= input$daterange[1] & Date <= input$daterange[2]),
                             PitcherTeam == "UCLA")
    
    a <- (
      if(input$pitcherSearch == "All"){
        DF
      } else {
        DF %>% filter(Pitcher == input$pitcherSearch)
      }
    )
    
    b <- (
      if(input$bDexterity == "All"){
        a
      } else {
        a %>% filter(BatterSide == input$bDexterity)
      }
    )
    
    c <- (
      if(input$pitchTypeP == "All"){
        b
      } else {
        b %>% filter(TaggedPitchType == input$pitchTypeP)
      }
    )
    
    d <- (
      if(input$hitTypeP == "All"){
        c
      } else {
        c %>% filter(HitType == input$hitTypeP)
      }
    )
    
    e <- (
      if(input$pitchCallP == "All"){
        d
      } else {
        d %>% filter(PitchCall == input$pitchCallP)
      }
    )
    
    f <- (
      if(input$pitchResultP == "All"){
        e
      } else {
        e %>% filter(PlayResult == input$pitchResultP)
      }
    )
    f
  })
  
  
  # Pitcher Opponent Filter:
  output$pitcherBatterOpponent <- renderUI({
    pickerInput("pitcherBatterOpponent", "Opposing Batter:", choices = c("All", as.character(unique(Trackman$Batter[Trackman$Pitcher == input$pitcherSearch]))),
                selected = "All", options = list(
                  `live-search` = TRUE,
                  size = 5
                ))
  })
  
  # Pitcher Filter Reset Button:
  observeEvent(input$resetP, {
    shinyjs::reset("pitcherfilters")
    shinyjs::reset("daterange")
  })
  
  # Reactive Hitter Inputs:
  hitterInput <- reactive(input$hitterSearch)
  hitterPitcherOpponentInput <- reactive(input$hitterPitcherOpponent)
  pDexterityInput <- reactive(input$pDexterity)
  pitchTypeInputB <- reactive(input$pitchTypeB)
  hitTypeInputB <- reactive(input$hitTypeB)
  pitchCallInputB <- reactive(input$pitchCallB)
  pitchResultInputB <- reactive(input$pitchResultB)
  
  HitterData <- reactive({
    
    DF <- Trackman %>% 
      filter(TaggedPitchType != "Undefined",
             TaggedPitchType != "Other",
             Date >= input$daterange[1] & Date <= input$daterange[2],
             BatterTeam == "UCLA")
    
    a <- (
      if(input$hitterSearch == "All"){
        DF
      } else {
        DF %>% filter(Batter == input$hitterSearch)
      }
    )
    
    b <- (
      if(input$pDexterity == "All"){
        a
      } else {
        a %>% filter(PitcherThrows == input$pDexterity)
      }
    )
    
    c <- (
      if(input$pitchTypeB == "All"){
        b
      } else {
        b %>% filter(TaggedPitchType == input$pitchTypeB)
      }
    )
    
    d <- (
      if(input$hitTypeB == "All"){
        c
      } else {
        c %>% filter(HitType == input$hitTypeB)
      }
    )
    
    e <- (
      if(input$pitchCallB == "All"){
        d
      } else {
        d %>% filter(PitchCall == input$pitchCallB)
      }
    )
    
    f <- (
      if(input$pitchResultB == "All"){
        e
      } else {
        e %>% filter(PlayResult == input$pitchResultB)
      }
    )
    f
  })
  
  # Hitter Opponent Filter:
  output$hitterPitcherOpponent <- renderUI({
    pickerInput("hitterPitcherOpponent", "Opposing Team:", choices = c("All", as.character(unique(Trackman$Pitcher[Trackman$Batter == input$hitterSearch]))),
                selected = "All", options = list(
                  `live-search` = TRUE,
                  size = 5
                ))
  })
  
  # Hitter Filter Reset Button:
  observeEvent(input$resetB, {
    shinyjs::reset("hitterfilters")
    shinyjs::reset("daterange")
  })
  
  # Pitcher Leaderboard:
  output$pitcherleaderboard <- renderDT(
    PitcherLeaderboard(PitcherData()),
    rownames = FALSE,
    colnames = c("Pitcher", "Count", "Velocity", "Spin Rate", "Induced Vertical Break", "Horizontal Break", "Extension"),
    filter = 'top',
    options = list(
      pageLength = 100,
      order = list(2, 'desc'),
      dom = 'ft'
    )
  )
  
  # Pitcher Plots:
  output$velospin <- renderPlot({
    
    VeloSpinPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP)
  
  output$releaseposition <- renderPlot({
    
    ReleasePositionPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP)
  
  output$breaks <- renderPlot({
    
    MovementPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP)
  
  output$location <- renderPlot({
    
    LocationPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP)
  
  output$swingplotP <- renderPlot({
    
    PitcherSwingPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP)
  
  # Pitcher Heat Maps:
  
  output$bipHeatMapP <- renderPlot({
    bipHeatMapFunctionP(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP)
  
  output$countHeatMapP <- renderPlot({
    countHeatMapFunctionP(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP)
  
  output$evHeatMapP <- renderPlot({
    evHeatMapFunctionP(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP)
  
  output$laHeatMapP <- renderPlot({
    laHeatMapFunctionP(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP)
  
  output$swingrateHeatMapP <- renderPlot({
    swingrateHeatMapFunctionP(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP)
  
  output$whiffrateHeatMapP <- renderPlot({
    whiffrateHeatMapFunctionP(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP)
  
  output$veloTrend <- renderPlot({
    veloTrendPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP)
  
  output$spinrateTrend <- renderPlot({
    spinrateTrendPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP)
  
  output$extensionTrend <- renderPlot({
    extensionTrendPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP)
  
  output$horzbreakTrend <- renderPlot({
    horzbreakTrendPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP)
  
  output$vertbreakTrend <- renderPlot({
    vertbreakTrendPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP)
  
  output$usageTrend <- renderPlot({
    usageTrendPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP)
  
  pitcherInput1 <- reactive(input$pitcherInput1)
  pitcherInput2 <- reactive(input$pitcherInput2)
  
  output$metrics1 <- renderDataTable({
    req(input$pitcherInput1 != "All")
    datatable(
      pitcherMetricsDF(PitcherData()),
      caption = htmltools::tags$caption(
        style = 'font-weight: bold;', input$pitcherInput1),
      rownames = FALSE,
      colnames = c("Pitch Type", "Count", "Velocity", "Spin Rate", "Horizontal Break", "Vertical Break", "Extension"),
      options = list(
        order = list(0, 'asc'),
        dom = 't'
      ))
  })
  
  output$metrics2 <- renderDataTable({
    req(input$pitcherInput2 != "All")
    datatable(
      pitcherMetricsDF(PitcherData()),
      caption = htmltools::tags$caption(
        style = 'font-weight: bold;', input$pitcherInput2),
      rownames = FALSE,
      colnames = c("Pitch Type", "Count", "Velocity", "Spin Rate", "Horizontal Break", "Vertical Break", "Extension"),
      options = list(
        order = list(0, 'asc'),
        dom = 't'
      ))
  })
  
  output$veloplot1 <- renderPlot({
    req(input$pitcherInput1 != "All")
    VeloSpinPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$veloplot2 <- renderPlot({
    req(input$pitcherInput2 != "All")
    VeloSpinPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$release1 <- renderPlot({
    req(input$pitcherInput1 != "All")
    ReleasePositionPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$release2 <- renderPlot({
    req(input$pitcherInput2 != "All")
    ReleasePositionPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$movement1 <- renderPlot({
    req(input$pitcherInput1 != "All")
    MovementPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$movement2 <- renderPlot({
    req(input$pitcherInput2 != "All")
    MovementPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$location1 <- renderPlot({
    req(input$pitcherInput1 != "All")
    LocationPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$location2 <- renderPlot({
    req(input$pitcherInput2 != "All")
    LocationPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$swings1 <- renderPlot({
    req(input$pitcherInput1 != "All")
    PitcherSwingPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$swings2 <- renderPlot({
    req(input$pitcherInput2 != "All")
    PitcherSwingPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$count1 <- renderPlot({
    req(input$pitcherInput1 != "All")
    countHeatMapFunctionP(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$count2 <- renderPlot({
    req(input$pitcherInput2 != "All")
    countHeatMapFunctionP(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$bip1 <- renderPlot({
    req(input$pitcherInput1 != "All")
    bipHeatMapFunctionP(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$bip2 <- renderPlot({
    req(input$pitcherInput2 != "All")
    bipHeatMapFunctionP(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$exitvelo1 <- renderPlot({
    req(input$pitcherInput1 != "All")
    evHeatMapFunctionP(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$exitvelo2 <- renderPlot({
    req(input$pitcherInput2 != "All")
    evHeatMapFunctionP(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$launchangle1 <- renderPlot({
    req(input$pitcherInput1 != "All")
    laHeatMapFunctionP(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$launchangle2 <- renderPlot({
    req(input$pitcherInput2 != "All")
    laHeatMapFunctionP(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$swingperc1 <- renderPlot({
    req(input$pitcherInput1 != "All")
    swingrateHeatMapFunctionP(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$swingperc2 <- renderPlot({
    req(input$pitcherInput2 != "All")
    swingrateHeatMapFunctionP(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$whiffperc1 <- renderPlot({
    req(input$pitcherInput1 != "All")
    whiffrateHeatMapFunctionP(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$whiffperc2 <- renderPlot({
    req(input$pitcherInput2 != "All")
    whiffrateHeatMapFunctionP(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$velotrend1 <- renderPlot({
    req(input$pitcherInput1 != "All")
    veloTrendPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$velotrend2 <- renderPlot({
    req(input$pitcherInput2 != "All")
    veloTrendPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$spintrend1 <- renderPlot({
    req(input$pitcherInput1 != "All")
    spinrateTrendPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$spintrend2 <- renderPlot({
    req(input$pitcherInput2 != "All")
    spinrateTrendPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$extension1 <- renderPlot({
    req(input$pitcherInput1 != "All")
    extensionTrendPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$extension2 <- renderPlot({
    req(input$pitcherInput2 != "All")
    extensionTrendPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$horzbreak1 <- renderPlot({
    req(input$pitcherInput1 != "All")
    horzbreakTrendPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$horzbreak2 <- renderPlot({
    req(input$pitcherInput2 != "All")
    horzbreakTrendPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$vertbreak1 <- renderPlot({
    req(input$pitcherInput1 != "All")
    vertbreakTrendPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$vertbreak2 <- renderPlot({
    req(input$pitcherInput2 != "All")
    vertbreakTrendPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$usage1 <- renderPlot({
    req(input$pitcherInput1 != "All")
    usageTrendPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  output$usage2 <- renderPlot({
    req(input$pitcherInput2 != "All")
    usageTrendPlot(PitcherData())
  }) %>%
    bindCache(input$pitcherSearch, input$pitcherBatterOpponent, input$bDexterity, input$pitchTypeP, 
              input$hitTypeP, input$pitchCallP, input$pitchResultP, input$pitcherInput1, input$pitcherInput2)
  
  # Hitter Leaderboard:
  output$hitterleaderboard <- renderDT(
    HitterLeaderboard(HitterData()),
    rownames = FALSE,
    colnames = c("Hitter", "Count", "Exit Velocity", "Launch Angle", "Batted Ball Spin Rate", "Distance"),
    filter = 'top',
    options = list(
      pageLength = 100,
      order = list(2, 'desc'),
      dom = 'ft'
    )
  )
  
  output$evlaPlot <- renderPlot({
    EVLAPlot(HitterData())
  }) %>%
    bindCache(input$hitterSearch, input$hitterPitcherOpponent, input$pDexterity, 
              input$pitchTypeB, input$hitTypeB, input$pitchCallB, input$pitchResultB)
  
  # output$evlaPlot2 <- renderPlot({
  #   EVLAPlot2(HitterData())
  # })
  
  output$evlaPlot3 <- renderPlot({
    EVLAPlot3(HitterData())
  }) %>%
    bindCache(input$hitterSearch, input$hitterPitcherOpponent, input$pDexterity, 
              input$pitchTypeB, input$hitTypeB, input$pitchCallB, input$pitchResultB)
  
  output$radialPlot <- renderPlot({
    radialPlot(HitterData())
  }) %>%
    bindCache(input$hitterSearch, input$hitterPitcherOpponent, input$pDexterity, 
              input$pitchTypeB, input$hitTypeB, input$pitchCallB, input$pitchResultB)
  
  output$opsChart <- renderPlot({
    ops(HitterData())
  }) %>%
    bindCache(input$hitterSearch, input$hitterPitcherOpponent, input$pDexterity, 
              input$pitchTypeB, input$hitTypeB, input$pitchCallB, input$pitchResultB)
  
  output$swingplotB <- renderPlot({
    HitterSwingPlot(HitterData())
  }) %>%
    bindCache(input$hitterSearch, input$hitterPitcherOpponent, input$pDexterity, 
              input$pitchTypeB, input$hitTypeB, input$pitchCallB, input$pitchResultB)
  
  output$contourplotB <- renderPlot({
    HitterContourPlot(HitterData())
  }) %>%
    bindCache(input$hitterSearch, input$hitterPitcherOpponent, input$pDexterity, 
              input$pitchTypeB, input$hitTypeB, input$pitchCallB, input$pitchResultB)
  
  # Hitter Heat Maps:
  
  output$bipHeatMapB <- renderPlot({
    bipHeatMapFunctionB(HitterData())
  }) %>%
    bindCache(input$hitterSearch, input$hitterPitcherOpponent, input$pDexterity, 
              input$pitchTypeB, input$hitTypeB, input$pitchCallB, input$pitchResultB)
  
  output$countHeatMapB <- renderPlot({
    countHeatMapFunctionB(HitterData())
  }) %>%
    bindCache(input$hitterSearch, input$hitterPitcherOpponent, input$pDexterity, 
              input$pitchTypeB, input$hitTypeB, input$pitchCallB, input$pitchResultB)
  
  output$evHeatMapB <- renderPlot({
    evHeatMapFunctionB(HitterData())
  }) %>%
    bindCache(input$hitterSearch, input$hitterPitcherOpponent, input$pDexterity, 
              input$pitchTypeB, input$hitTypeB, input$pitchCallB, input$pitchResultB)
  
  output$laHeatMapB <- renderPlot({
    laHeatMapFunctionB(HitterData())
  }) %>%
    bindCache(input$hitterSearch, input$hitterPitcherOpponent, input$pDexterity, 
              input$pitchTypeB, input$hitTypeB, input$pitchCallB, input$pitchResultB)
  
  output$swingrateHeatMapB <- renderPlot({
    swingrateHeatMapFunctionB(HitterData())
  }) %>%
    bindCache(input$hitterSearch, input$hitterPitcherOpponent, input$pDexterity, 
              input$pitchTypeB, input$hitTypeB, input$pitchCallB, input$pitchResultB)
  
  output$whiffrateHeatMapB <- renderPlot({
    whiffrateHeatMapFunctionB(HitterData())
  }) %>%
    bindCache(input$hitterSearch, input$hitterPitcherOpponent, input$pDexterity, 
              input$pitchTypeB, input$hitTypeB, input$pitchCallB, input$pitchResultB)
  
  output$statcastStats <- renderDataTable({
    req(input$hitterSearch != "All")
    datatable(
      statcastTable(HitterData()),
      caption = htmltools::tags$caption(
        style = 'font-weight:bold;', input$hitterSearch),
      rownames = FALSE,
      colnames = c("Pitch Type", "Pitches", "Batted Balls", "Barrels", "Barrel %", "EV", "Max EV", "LA", "Distance", "Sweet Spot %", "Hard Hit %", "Whiff %"),
      options = list(
        dom = 't'
      ))
  })
  
  output$bypitchstatcastStats <- renderDataTable({
    req(input$hitterSearch != "All")
    datatable(
      bypitchstatcastTable(HitterData()),
      rownames = FALSE,
      colnames = c("Pitch Type", "Pitches", "Batted Balls", "Barrels", "Barrel %", "EV", "Max EV", "LA", "Distance", "Sweet Spot %", "Hard Hit %", "Whiff %"),
      options = list(
        dom = 't'
      ))
  })
  

  output$advancedstats = renderDataTable({
    table <- datatable(
      advancedstats_func(Trackman_csv),
      rownames = TRUE,
      options = list(
        dom = 't'
      ))
    table
  })
  
  
  output$wOBAtable <- renderDataTable({
    datatable(
      xwOBAfunction(HitterData()),
      rownames = FALSE,
      options = list(
        dom = 't'
      ))
  })
  
  
  output$zonelocation <- renderPlot({
    zone_loc_plots <- zonelocationsucess(HitterData())
    zone_loc_plots$ncol = 3
    do.call(grid.arrange, zone_loc_plots)
  }) %>%
    bindCache(input$hitterSearch, input$hitterPitcherOpponent, input$pDexterity,
              input$pitchTypeB, input$hitTypeB, input$pitchCallB, input$pitchResultB)
  
  output$swingdecision <- renderPlot({
    swing_decis(HitterData())
  }) %>%
    bindCache(input$hitterSearch, input$hitterPitcherOpponent, input$pDexterity, 
              input$pitchTypeB, input$hitTypeB, input$pitchCallB, input$pitchResultB)
  
  
  
  
  histInput <- reactive(input$histPlot)
  
  output$histogram <- renderPlot({
    histogramPlot(HitterData())
  }) %>%
    bindCache(input$hitterSearch, input$hitterPitcherOpponent, input$pDexterity, 
              input$pitchTypeB, input$hitTypeB, input$pitchCallB, input$pitchResultB)
  
  
}

shinyApp(ui, server)
