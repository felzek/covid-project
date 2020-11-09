library(MASS)
library(car)
Positive_Covid <- read.csv(file = file.choose())
is.data.frame(Positive_Covid)
Positive_Covid
names(Positive_Covid)[names(Positive_Covid) == "ï..2020_Week"] <- "Week_in_2020"

# Linear Regression Analysis
fit <- lm(Percent_Change_in_Covid ~ Percent_Change_in_CLI + Percent_Change_in_ILI, data = Positive_Covid)
summary(fit)
4
# diagnostics plot
layout(matrix(c(1,2,3,4),2,2)) # optional 4 graphs/page
plot(fit)
car::vif(fit)

# apply box-cox transform
boxcox(fit, family = "yjPower", plotit = TRUE)

y_var_transformed <- yjPower(Positive_Covid$Percent_Change_in_Covid,-1.1)
x_var_1 <- Positive_Covid$Percent_Change_in_CLI
x_var_2 <- Positive_Covid$Percent_Change_in_ILI

fit2 <- lm(y_var_transformed ~ x_var_1 + x_var_2 + x_var_1:x_var_2)
layout(matrix(c(1,2,3,4),2,2)) # optional 4 graphs/page
plot(fit2)
car::vif(fit2)