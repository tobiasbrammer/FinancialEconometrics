
################################################################################
### Problem 1                                                                ###
################################################################################

# Theoretical excercise...

################################################################################
### Problem 2                                                                ###
################################################################################

source("/Users/tobiasbrammer/Library/Mobile Documents/com~apple~CloudDocs/Documents/Aarhus Uni/7. semester/FinancialEconometrics/Functions/KalmanFilter.r")

### Point 2)
# Write a code to simulate from the SV model reported in slide 31 of Lecture 7.

simulate_sv <- function(obs, sigma, rho, sigma2_eta) {
    #' Function to simulate from the model:
    #' y_t = sigma*exp(w_t/2)*z_t, z_t ~ iid N(0,1)
    #' w_t = rho * w_{t-1} + eta_t, eta_t ~ iid N(0, sigma_eta^2)
    #'
    #' obs:         is the length of sample to simulate
    #' sigma:       is the constant in the measurement equation
    #' rho:         is the autoregressive parameter of the log volatility
    #' sigma2_eta:  is the variance of the volatility shocks
    w <- numeric(obs)
    eta <- rnorm(obs, mean = 0, sd = sqrt(sigma2_eta))
    zeta <- rnorm(obs, mean = 0, sd = 1)

    # initialize w to unconditional distribution
    w[1] <- rnorm(1, mean = 0, sd = sqrt(sigma2_eta / (1 - rho^2)))

    for (t in seq(2, obs)) {
        w[t] <- rho * w[t - 1] + eta[t]
    }

    r <- sigma * exp(w / 2) * zeta

    return(
        list(
            "r" = r,
            "w" = w
        )
    )
}


### Point 3)
# Simulate T = 1000 observations from the SV model with
# sigma = 1, rho = 0.9, and sigma2_eta = 0.25. Set the seed to 123.

set.seed(123)
sv_sim <- simulate_sv(1000, sigma = 1, rho = 0.9, sigma2_eta = 0.25)


### POINT 4
# Write a function that maximize the quasi likelihood computed via
# the Kalman filter for the SV model of the previous point.
# The likelihood to maximize is defined in slide 23 of Lecture 7.

quasi_ml_sv <- function(y) {
    #' This function maximizes the Quasi Log Likelihood
    #' computed by the Kalman Filter for a log-linearized
    #' stochastic volatility model.
    #'
    #' The SV model is
    #' y_t = sigma*exp(w_t/2)*z_t, z_t ~ iid N(0,1)
    #' w_t = rho * w_{t-1} + eta_t, eta_t ~ iid N(0, sigma_eta^2)
    #' It's log linearized version is
    #' zeta_t = mu + w_t + eps_t,
    #' w_t = rho * w_{t-1} + eta_t, eta_t ~ iid N(0, sigma_eta^2)
    #' We have that E[eps_t|F_{t-1}] = 0, and E[eps_t^2|F_{t-1}] = pi^2/2
    #' and mu = log(sigma^2) + E[log(z_t^2)]
    #' where E[log(z_t^2)] = -1.270376
    #'
    #' y are the "level" non-transformed returns
    #' 
    #' # THIS FUNCTION WILL BE USEFUL LATER!
    # Kalman filter and smoother for the model
    # y_t = alpha_t + sigma * eps_t
    # alpha_{t+1} = phi * alpha_t + eta * xi_t
    # vPar is the vector of parameters vPar = (phi, sigma, eta)
    # note that the vPar contains the standard deviations (sigma and eta)
    # and not the variances (sigma^2, eta^2).
    # vY is the vector of observations
    KalmanFilter_AR1plusNoise <- function(vY, vPar, Smoothing = FALSE) {
    dPhi <- vPar[1]
    dSigma <- vPar[2]
    dEta <- vPar[3]

    mY <- matrix(vY, nrow = 1)
    mZ <- matrix(1, 1, 1)
    mS <- matrix(dSigma^2, 1, 1)
    mT <- matrix(dPhi, 1, 1)
    mH <- matrix(1, 1, 1)
    mQ <- matrix(dEta^2, 1, 1)
    a1 <- 0
    mP1 <- matrix(dEta^2 / (1 - dPhi^2), 1, 1)

    return(
        kalman_filter(mY, mZ, mS, mT, mH, mQ, a1, mP1, Smoothing)
    )
}


    # number of observations
    obs <- length(y)

    if (any(y == 0)) {
        y[y == 0] <- mean(y)
    }

    # transform returns
    y_transform <- log(y^2)
    # demean returns
    y_transform <- y_transform - mean(y_transform)

    # starting parameters
    params <- c(
        cor(y_transform[-1], y_transform[-obs]),
        var(y_transform) * 0.1
    )

    # optimize the likelihood
    optimizer <- optim(
        params,
        function(params, y_transform, obs) {
            rho <- params[1]
            sigma2_eta <- params[2]

            params_tot <- c(
                rho, sqrt(pi**2 / 2), sqrt(sigma2_eta)
            )
            kalman <- KalmanFilter_AR1plusNoise(
                y_transform, params_tot,
                Smoothing = FALSE
            )

            return(
                -kalman$dLLK
            )
        },
        method = "L-BFGS-B", lower = c(0.001, 0.001), upper = c(0.99, 1.0),
        y_transform = y_transform, obs = obs
    )

    # extract estimated parameters
    # compute the vector of total parameters
    rho <- optimizer$par[1]
    sigma2_eta <- optimizer$par[2]
    params_tot <- c(optimizer$par[1], sqrt(pi^2 / 2), sqrt(optimizer$par[2]))

    # filtering and smoothing
    kalman <- KalmanFilter_AR1plusNoise(
        y_transform, params_tot,
        Smoothing = TRUE
    )

    model_params <- c(
        # I have no idea where 1.270376 comes from
        sigma = exp((mean(log(y^2)) + 1.270376) / 2),
        rho = rho,
        sigma2_eta = sigma2_eta
    )

    return(
        list(
            params = model_params,
            kalman = kalman
        )
    )
}



### POINT 5
# Estimate the model on the simulated data.
# Can you recover the true parameters?


fit <- quasi_ml_sv(sv_sim$r)
fit$params

mKF <- fit$kalman

# Plot the smoothed shocks
plot(t(mKF$eps_smoot), type = "l", col = "blue", lwd = 2, xlab = "Time", ylab = "Volatility")
lines(t(mKF$a_pred), col = "red", lwd = 2)

# Plot the smoothed volatility
plot(t(mKF$a_pred), type = "l", col = "blue", lwd = 2, xlab = "Time", ylab = "Volatility")

# Output all elements of list mKF
names(mKF)




# The estimated parameters are
# sigma = 1.0671994
# rho   = 0.9073020
# sigma2eta = 0.1423963

# We see that estimated for sigma and rho
# are reasonable but sigma2eta is heavily
# underestimated. If you increase T = 5000
# using the same seed you obtain
# sigma = 0.9915461
# rho   = 0.8900296
# sigma2eta = 0.2628427
# such that, as expected, the precision of the estimates
# increases with T

################################################################################
### Problem 3                                                                ###
################################################################################

# Download the time series of the S&P500 index from Yahoo finance from
# 2005-01-01 to 2018-01-01 and compute the percentage log returns.
# Replace the zero returns with their empirical mean. Estimate the SV model
# by QML. Use the mapping between the SV specification you estimated and the
# one of Lecture 6 in order to compare your estimates with those obtained
# from the GMM estimator in Exercise Set 2.

rm(list=ls())

setwd("/Users/tobiasbrammer/Library/Mobile Documents/com~apple~CloudDocs/Documents/Aarhus Uni/7. semester/FinancialEconometrics/Functions")
source("KalmanFilter.r")

setwd("/Users/tobiasbrammer/Library/Mobile Documents/com~apple~CloudDocs/Documents/Aarhus Uni/7. semester/FinancialEconometrics/Problem Sets/Problem Set 3")

library(quantmod)

price <- getSymbols("^GSPC", from = "2005-01-01", to = "2018-01-01", auto.assign = FALSE)

# extract and parse Adjusted Close
price <- price$GSPC.Adjusted
price <- as.numeric(price)

# auto-removes the NA observation
price <- diff(log(price)) * 100

# replace zero returns with their empirical mean
price[price == 0] <- mean(price)

setwd("/Users/tobiasbrammer/Library/Mobile Documents/com~apple~CloudDocs/Documents/Aarhus Uni/7. semester/FinancialEconometrics/Problem Sets/Problem Set 3")
source("GMMEstimation_SV.r")
source("quasi_ml_sv.r")
# fit QML model
fit_qml <- quasi_ml_sv(price)

# fit GMM model
fit_gmm <- GMM_Estimator(price)

# estimated parameters
fit_qml$params
fit_gmm$par


# map between the GMM and QML estimate
# sigma = exp(omega/(2*(2-rho)))
exp(fit_gmm$par[1] / (2 * (1.0 - fit_gmm$par[2])))
