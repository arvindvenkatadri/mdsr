#' Wrangle babynames data
#' @importFrom dplyr mutate_ select_ bind_rows rename_ inner_join %>%
#' @import babynames
#' @importFrom stats approx
#' @export
#' @return a \code{\link[dplyr]{tbl_df}} similar to \code{\link[babynames]{babynames}}
#' with a column for the estimated number of people alive in 2014.
#' @examples 
#' 
#' BabynameDist <- make_babynames_dist()
#' BabynameDist %>%
#'   filter(name == "Benjamin")
#' 

make_babynames_dist <- function() {
  actuarial <- babynames::lifetables %>%
    dplyr::mutate_(age_today = ~x, 
            alive_prob = ~lx / 100000, 
            more_years = ~ex, 
            life_exp = ~x + ex) %>%
    dplyr::filter_(~year + x == 2014) %>%
    dplyr::select_(~year, ~sex, ~age_today, ~alive_prob, ~life_exp)
  
  # Unfortunately, the actuarial tables only contain entries for people born each decade, not each year. Following FiveThirtyEight's lead we will linearly interpolate the missing values using the \func{approx} function. 
  
  years <- min(actuarial$year):max(actuarial$year)
  men <- actuarial %>%
    dplyr::filter_(~sex == "M") %>%
    approximate(years = years)
  women <- actuarial %>%
    dplyr::filter_(~sex == "F") %>%
    approximate(years = years)
  actuarial_interp <- dplyr::bind_rows(men, women)
  actuarial_interp <- actuarial_interp %>%
    dplyr::rename_(year = ~x, alive_prob = ~y) %>%
    dplyr::mutate_(sex = ~c(rep("M", length(years)), rep("F", length(years))))
  
  # Finally, we will construct the data set that we need by joining the actuarial information with the baby names data. 
  
  BabynameDist <- babynames::babynames %>%
    dplyr::inner_join(actuarial_interp, by = c("year", "sex")) %>%
    dplyr::mutate_(count_thousands = ~n / 1000, 
            age_today = ~2014 - year, 
            est_alive_today = ~n * alive_prob)
  
}

approximate <- function(data, years) {
  stats::approx(data$year, data$alive_prob, xout = years) %>%
    as.data.frame()
}


