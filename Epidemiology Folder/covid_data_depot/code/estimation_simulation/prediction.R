rm(list=ls())
gc()

library(tidyverse)
library(haven)

# load data
data <- read.csv("~/covid_data.csv")

# load estimates from the regression
# coefficients and date fixed effects
b_se <- read.csv("~/coef_date_FE.csv")
home_ratio_par <- b_se$coef[1]
Log_Y_par <- b_se$coef[2]
avg_temp_par <- b_se$coef[3]
humidity_par <- b_se$coef[4]
const <- b_se$coef[dim(b_se)[1]]

# last 7 days date_FE
date_FE <- b_se %>% filter(coef_name == "Idate") %>% arrange(date) %>% 
  slice(tail(row_number(), 7)) %>% select(coef, date)

# Create day-of-week for merging later
dow <- data %>% select(date, dow) %>% unique()
date_FE <- date_FE %>% left_join(dow, by="date") %>% 
  group_by(dow) %>% summarize(date_FE = mean(coef))
# The constant is the date_FE of the first date in the data, which
# is the baseline of all the remaining date_FE. Hence, adding the 
# constant to all remaining date_FE
date_FE <- date_FE %>% mutate(date_FE = date_FE + const)

# load fips_FE
fips_FE <- read.csv("~/Downloads/county_FE.csv")

# load historical temperature, rain, and humidity data
hist_temp <- read_dta("./historical_daily_temp.dta")
hist_temp <- hist_temp %>% mutate_all(as.numeric)

hist_humidity <- data %>% select(fips, humidity, month) %>% 
  filter(month>=4) %>% group_by(fips) %>% 
  summarise(avg_humidity = mean(humidity, na.rm = TRUE)) %>% ungroup

# combine with fips_FE
data <- data %>% mutate(y_pred = 0) %>% 
  right_join(fips_FE, by="fips")

# combine with date_FE
data <- data %>% left_join(date_FE, by="dow")
data <- data %>% 
  select(fips, date, dow, month, day, fips_FE, date_FE, cum_case_2,
         avg_temp, humidity, pop, y_pred, social_distancing)
# time invariant variables at County level
data_time_invariant <- data %>% select(fips, fips_FE, pop) %>% unique()

social_dist_feb <- read.csv("~/Downloads/social_dist_feb.csv")
social_dist_feb_apr <- read.csv("~/Downloads/social_dist_apr.csv") #apr 2nd week is max!!
# last_week is a holder for the final week of social_distancing data
social_dist_last_week <- read.csv("~/Downloads/social_dist_last_week.csv") %>% select(-date)
# post_est is for social-distancing data post estimation (for out-of-sample prediction)
social_dist_post_est <- read.csv("~/Downloads/social_dist_post_est.csv")

social_dist <- social_dist_last_week %>% 
  left_join(social_dist_feb, by=c("fips", "dow")) %>% 
  left_join(social_dist_apr, by=c("fips", "dow")) %>% 
  rename(social_dist_min = social_dist_feb)

social_dist <- social_dist %>%
  mutate(social_dist_50 = (social_dist_apr + social_dist_min)/2,
         social_dist_75 = (social_dist_apr + social_dist_50)/2,
         social_dist_25 = (social_dist_50 + social_dist_min)/2)


######## expand data for forecasting
## extract fips
fips_expand <- fips_FE %>% select(fips) %>% unique()
## month
month_expand <- data.frame(month=4:9)
## day
day_expand <- data.frame(day=1:31)
## combine fips, month, day and also drop impossible dates
data_expand <- fips_expand %>% crossing(month_expand) %>% crossing(day_expand)
data_expand <- data_expand %>% 
  filter(!(month == 4) & 
           !(month == 5 & day <= 18) & 
           !(month == 6 & day == 31) & !(month == 9 & day == 31)) %>% 
  arrange(month, day, fips)

## date to match stata's dates; also day-of-week
## from 5/19 till 9/30
day_expand <- 22054:22188
month_day <- data_expand %>% select(month, day) %>% unique()
## 19 weeks plus 2 days
dow_expand <- c(rep(c(2:6, 0:1), 19), 2:3)
day_expand <- as.data.frame(cbind(month_day, dow_expand, day_expand))
names(day_expand) <- c("month", "day", "dow", "date")
data_expand <- data_expand %>% left_join(day_expand, by=c("month", "day")) 

# historical weather data for May-August; fillin missing fips with state weather 
data_expand <- data_expand %>% 
  left_join(hist_temp, by=c("fips", "date")) %>% mutate(state = floor(fips/1000)) %>% 
  group_by(state, date) %>% mutate(state_temp = mean(avg_temp, na.rm=TRUE)) %>% 
  ungroup %>% mutate(avg_temp = coalesce(avg_temp, state_temp))
data_expand <- data_expand %>% left_join(hist_humidity, by="fips") %>% 
  mutate(humidity = avg_humidity)

# social_dist merge
data_expand <- data_expand %>% left_join(social_dist, by=c("fips", "dow"))
# bring in the social_dist post estimation
data_expand <- data_expand %>% left_join(social_dist_post_est, by=c("fips", "date"))

# fips time invariant merge
data_expand <- data_expand %>% left_join(data_time_invariant, by=c("fips"))
# date_FE merge
data_expand <- data_expand %>% left_join(date_FE, by=c("dow")) %>% 
  select(-state, -state_temp, -avg_humidity)

 
save.image("./data.RData")


load("./data.RData")
################################
##### current Level of social distancing (most recent week)
data2 <- bind_rows(data, data_expand) %>% arrange(fips, date) %>%
  mutate(social_dist = coalesce(social_dist, social_dist_post_est), cum_case_2_copy = cum_case_2) %>%
  mutate(social_dist = coalesce(social_dist, social_dist_last_week))

for (day in 22054:22084){
  data_temp <- data2 %>% 
    select(cum_case_2, date, pop, fips, fips_FE, date_FE, avg_temp, humidity, social_dist) %>% 
    group_by(fips) %>% 
    mutate(ylag2 = lag(cum_case_2, n = 2L, order_by=date, default = 1),
           ylag8 = lag(cum_case_2, n = 8L, order_by=date, default = 1),
           ylag1 = lag(cum_case_2, n = 1L, order_by=date, default = 1)) %>% ungroup
  
  day_ind = which(data2$date == day)
  
  # pmax is to assure Y does not go to 0, which is fairly rare
  Y_temp <- data_temp[day_ind, ] %>% select(ylag8, ylag2) %>% 
    mutate(Y_temp = pmax(ylag2 - ylag8, 0)) %>% select(Y_temp)
  
  Y <- Y_temp ^ Log_Y_par
  
  # pmax is to assure S does not go negative, which is fairly rare
  S <- data_temp[day_ind, ] %>% select(ylag1, pop) %>% 
    mutate(S = pmax(1-ylag1/pop, 0)) %>% select(S)
  
  covariates <- data_temp[day_ind, ] %>% 
    select(fips_FE, date_FE, avg_temp, humidity, social_dist)
  fips_FE_exp <- exp(covariates$fips_FE)
  date_FE_exp <- exp(covariates$date_FE)
  avg_temp_exp <- exp(covariates$avg_temp * avg_temp_par)
  social_dist_exp <- exp(covariates$social_dist * social_dist_par)
  humidity_exp <- exp(covariates$humidity * humidity_par)
  
  R <- fips_FE_exp * date_FE_exp * avg_temp_exp * social_dist_exp * humidity_exp
  
  y <- (R * S * Y)[,1]
  
  data2$cum_case_2[day_ind] <- y + data_temp$ylag1[day_ind]
  data2$y_pred[day_ind] <- y
  
  print(day)
}

sim_dat_current <- data2 %>% filter(date>=22015) %>% 
  select(fips, date, cum_case_2)

pred_dat_out <- sim_dat_current

write.csv(pred_dat_out, file="./pred_dat.csv", row.names = FALSE)


