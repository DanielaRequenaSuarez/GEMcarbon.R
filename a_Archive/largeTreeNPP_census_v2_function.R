# Written: C�cile Girardin July 2014

## This script estimates largeTreeNPP annual NPP values based on census data
# The monthly values you get from this code are plot-level values, as all the trees in the plot are censused. 
# Once you sum all monthly values from this, you get the annual value for the plot. 
# That is the most reliable annual value. 
# We then use this to estimate a scaling factor for the monthly dendrometer data (NPPcensus ha-1 yr-1 / NPPdend ha-1 yr-1).

# requires one .csv file: 
# census   <- read.csv() 

## column names:
#plot
#subplot
#tag
#DAP
#palm
#altura_tot_est
#DAPaltura_m
#Densidade_de_madeira_g_cm3
#Dendrometer_altura_m

NPPacw_census1 <- function(census, plotname, census1_year="Default", census2_year="Default", allometric_option="Default", height_correction_option="Default") {
  
  # load libraries
  library(sqldf)
  
  ## Set of allometric equations after Chave et al. 2005 and Chave et al. 2014 are defined in allometricEquations.R. Options defined here:
  if (allometric_option == 2 | allometric_option == "dry") {
    allometrix <- 2
    print("dry equation  is used for estimating AGB, model I.3 (see Chave et al., 2005)")
  } else if (allometric_option == 3 | allometric_option == "moist" | allometric_option == "Default" | allometric_option == 1 | allometric_option == "moist_ped") {
    allometrix <- 3
    print("moist equation  is used for estimating AGB, model I.6 (see Chave et al., 2005)")
  } else if (allometric_option == 4 | allometric_option == "wet") {
    allometrix <- 4
    print("wet equation  is used for estimating AGB, model I.3 (see Chave et al., 2005)")
  } else if (allometric_option == 5 | allometric_option == "Chave2014") {
    allometrix <- 5
    print("pantropical equation is used for estimating AGB, model (4) (see Chave et al., 2014)")
  } else {
    print("Please specify a valid allometric_option!")
    return()
  }
  
  ## get data for all trees that are in the plot selected
  cen <- subset(census, plot==plotname)
  # rename columns
  #colnames(cen) <- c("plot", "sp", "tag", "dbh", "height", "density", "year", "month", "day", "plot_code")
    
  # Density: look up density at spp / genus level from global density db Zanne
  
  ## fill implausible values:
  cen$height[which(cen$height>120)] <- 120 
  cen$height[which(cen$height<2)]   <- 2 
  xdensity <- mean(cen$density, na.rm=T) 
  cen$density[which(is.na(cen$density)) | which(cen$density==0)] <- xdensity 
  
  ## OPTIONS
  ## Height correction options
  if (height_correction_option == 1 | height_correction_option == "Default" ) {
    predheight <- 1
    print("If you have height for more than 50 trees in your plot, estimate local diameter-height relationship. If not, choose height correction option 2.")
  } else if (height_correction_option == 2) {
    predheight <- 2
    print("height correction estimated as described by Feldpauch et al. (2012). Please check Feldpauch regional parameters in the code. Default is Brazilian shield.")
  } else {
    print("Please specify a valid height_correction_option!")
    return()
  }
  
  # dates option
  if (census1_year == "Default" ) {
    census1_year <- min(census$year)
    print("Using first and last years of the dataset as census interval. Please precify census1_year and census2_year.")
  }
  
  if (census2_year == "Default" ) {
    census2_year <- max(census$year)
    print("Using first and last years of the dataset as census interval.")
  }
  
  ## Correct for missing tree heights
  # missing height function
  
  h.est=function(dbh, h){
    l      =lm(h~dbh)
    coeffs = coefficients(l)
    pred.h = coeffs[1] + coeffs[2]*dbh
  }
  
  # Option 2: you have height for less than 50 trees in your plot. Use Fedpauch equation.

  #ADD PARAMETER: Feldpauch region. 
  
  ## Feldpauch correction procedure for heights, diameters and densitys:
    # Brazilian shield
    Bo    = 0.6373
    B1    = 0.4647  # E.C. Amazonia
    
    So1   = 0.012  # E.C. Amazonia
    Abar  = 20.4  # mean cenetered basal area m-2 ha-1
    
    n01   = 0.0034 # E.C. Amazonia
    Pvbar = 0.68 # mean centered precipitation coefficient of variation
    
    n02   = -0.0449 # E.C. Amazonia
    Sdbar = 5     # mean centered dry season length no months less than 100mm
    
    n03   = 0.0191  # E.C. Amazonia
    Tabar = 25.0  # mean centered annual averge temperature
    
    
  # Define height options
  if (predheight == 1) {
    w <- which(is.na(cen$height))
    h.pred <- h.est(cen$dbh, cen$height)
    cen$height[w] <- h.pred[w]
  } else if (predheight == 2) {
    w <- which(is.na(cen$height))
    cen$height[w] <- 10^(Bo + B1*log10(cen$dbh[w]/10) + Abar*So1 + n01*Pvbar + n02*Sdbar + n03*Tabar)
  } 
  
  er = 0.1 # .1cm sampling error is trivial compared to systematic error of allometric equation. Change this see Chave et al. 2005.
  
  ## loop through each tree to estimate biomass (bm) and convert to above ground carbon (agC)
  for (ii in 1:length(cen$tag)) {
    thistree <- which(cen$tag == cen$tag[ii] & cen$year == cen$year[ii])     
    dbh_tree <- cen$dbh[thistree]
    den_tree <- cen$density[thistree]
    h_tree   <- cen$height[thistree]
    
    # this uses allometric equations from allometricEquations.R
    if (allometrix == 2) {
      bm <- Chave2005_dry(diax=dbh_tree, density=den_tree, height=h_tree)
    } else if (allometrix == 3) {
      bm <- Chave2005_moist(diax=dbh_tree, density=den_tree, height=h_tree)
    } else if (allometrix == 4) {
      bm <- Chave2005_wet(diax=dbh_tree, density=den_tree, height=h_tree)
    } else if (allometrix == 5) {
      bm <- Chave2014(diax=dbh_tree, density=den_tree, height=h_tree)
    }
      
    ## TO DO ## error treatment remains to be done!
    
    # Unit conversions are not carried out in allometricEquations.R
    cen$agC[ii] <- (bm)*(1/(2.1097*1000)) # convert kg to Mg=1/1000=10 and convert to carbon = 47.8%                        
  }
  
  ## TO DO ## ADD TERHI's HEIGHT PROPAGATION CORRECTION
   
  ## find global start and end month:
  cen$min_date <- NULL
  cen$max_date <- NULL
  cen$date     <- as.Date(paste(cen$year, cen$month, cen$day, sep="."), format="%Y.%m.%d") 
  
  # temp <- subset(cen, cen$year == census1_year & cen$year == census2_year) # 
  agC_mydates     <- subset(cen, cen$year == census1_year | cen$year == census2_year, select = c(plot, tag, year, month, day, date, agC))
  
  for (i in 1:length(agC_mydates$tag)) {
    min_date <- as.character(min(agC_mydates$date)) 
    max_date <- as.character(max(agC_mydates$date)) 
  }
  
  start_date <- as.Date(format(min(strptime(min_date, format="%Y-%m-%d")))) 
  end_date   <- as.Date(format(max(strptime(max_date, format="%Y-%m-%d"))))
  census_interval <- as.numeric(difftime(end_date, start_date, units="days"))
  
  # (AG carbon.2 - AG carbon.1) / census_interval
  agC_1         <- subset(cen, cen$year == census1_year, select = c(plot, tag, year, month, day, agC))
  agC_2         <- subset(cen, cen$year == census2_year, select = c(plot, tag, year, month, day, agC))
  agC_1$uid     <- paste(agC_1$tag, agC_1$year, agC_1$month, agC_1$day, sep=".") 
  agC_2$uid     <- paste(agC_1$tag, agC_1$year, agC_1$month, agC_1$day, sep=".")
  npp           <- sqldf("SELECT agC_1.plot, agC_1.tag, agC_1.year, agC_1.month, agC_1.agC , agC_2.agC FROM agC_1 JOIN agC_2 ON agC_1.uid = agC_2.uid")
  colnames(npp) <- c("plot", "tag", "year", "month", "agC.1", "agC.2")
  npp_day       <- (npp$agC.2-npp$agC.1) / census_interval
  NPPacw_MgC_ha_yr <- (sum(npp_day, na.rm=T))*365 
 
  # Talbot census correction function
  NPPcorr = NPPacw_MgC_ha_yr + (0.0091 * NPPacw_MgC_ha_yr) * (census_interval/365)
  
return(NPPacw_MgC_ha_yr)
}

# w=which(!is.na(data$biomass.2003) & !is.na(data$biomass.2007)) # id surviving trees to estimate biomass growth
# w2=which(!is.na(data$biomass.2003) & is.na(data$biomass.2007)) # id dying trees
# w3=which(is.na(data$biomass.2003) & !is.na(data$biomass.2007)) # id recruiting trees
  
