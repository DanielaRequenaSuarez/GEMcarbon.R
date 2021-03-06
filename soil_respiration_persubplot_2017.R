### Function Soil respiration:
# This function calculates soil respiration and uses input data specified in the RAINFOR-GEM manual.
# Based on matlab code developed by Chris Doughty, 2011.
# Last edited: Cecile Girardin, 10.09.2015

### Required Data:
# dataframe of total soil respiration
# dataframe of partition respiration 
# dataframe of control respiration 
# plotname: specify plot_code of the plot you are working with (eg. WAY-01)
# ret: data-format of return values: "monthly.means.ts" or "monthly.means.matrix"
# plotit: logical (T/F), plot a quick graphical summary of the data?
# User has to specify either elevation or pressure.


#load packages
library(sqldf)
require(ggplot2)


### read data for option 1:
setwd("~/Github/gemcarbon_data/processed_data/soil_respiration_flux")
dataresc <- read.table("flux_control_ESP01_09to14.csv", sep=",", header=T)

dataresc$sub_plot <- dataresc$raw_consr.sub_plot

dataresp <- read.table("flux_part_ESP_01_2013.csv", sep=",", header=T)
datarest <- read.table("flux_total_ESP01_09to14.csv", sep=",", header=T)

# dataresp$collar_height_cm has a lot of NAs, I am replacing NAs by mean(dataresp$collar_height_cm, na.rm=T)
dataresp$collar_height_cm[is.na(dataresp$collar_height_cm)] <- mean(dataresp$collar_height_cm, na.rm=T)

pressure = 1013.25
plotname = "ESP-01"
partitioningoption = 1
elevation = "Default"
T_ambient="Default"
plotit=T

### read data for option 2:
#setwd("/Users/Cecile/Dropbox/Carbon_Use_Efficieny_R/testing/soilresp")

#dataresc <- read.table("Resconallsam.csv", sep=",", header=T)
#dataresp <- read.table("Resparallsam.csv", sep=",", header=T)
#datarest <- read.table("Restotallsam.csv", sep=",", header=T)
#pressure = 1013.25
#plotname = 1.1
#partitioningoption = 2
#elevation = "Default"
#pressure="Default"
#T_ambient="Default"

# read correction functions:
script.dir <- dirname(sys.frame(1)$ofile)
source(paste0(script.dir,"/soilrespiration_auxfunctions.R"))
soilrespiration <- function(datarest,dataresp,dataresc, plotname, ret="monthly.means.ts", # Add tube radius as a parameter, change A to A <- pi*(rad^2) 
                            partitioningoption="Default",
                            pressure="Default", elevation="Default", T_ambient="Default",
                            plotit=F) {
  
  # Partitionning option 
  if (partitioningoption=="Default") {
    print("Warning! No partitioning option (see RAINFOR manual, p. 56) was specified.")
    print("Please specify the variable 'partitioningoption' in the function call.")
    partitioningoption=1
  }
  
  if (partitioningoption==2) {
    print("Code is running on partitioning option 2 (RAINFOR-GEM manual, p. 56).")
  }
  
  if (partitioningoption==1) {
    print("Code is running on partitioning option 1 (RAINFOR-GEM manual, p. 56).")
  }
  
  if (pressure=="Default" & elevation=="Default" & T_ambient=="Default") {
    print("WARNING! Neither ambient pressure nor site elevation was specified")
    print("Calculations will be based on p=1013.25 hPa (sea level) and temperature-independent barometric equation.")
    pressure <- 1013.25
  }
  
  if (pressure!="Default") {
    print("Ambient pressure was specified and will be used for flux correction.")
  }
  
  if (pressure=="Default" & elevation!="Default" & T_ambient=="Default") {
    print("Ambient pressure and temperature was not specified. Ambient pressure for flux correction is calculated from elevation
          using the temperature-independent barometric equation.")
    pressure <- barometric_equation(elevation)
  }
  
  if (pressure=="Default" & elevation!="Default" & T_ambient!="Default") {
    print("Ambient pressure was not specified. Ambient pressure for flux correction is calculated from elevation
           and ambient temperature (in 0C) using the temperature-dependent barometric equation.")
    pressure <- barometric_equation_T(elevation, T_ambient)
  }
  
  
  ### Defaults for chamber volume and tube area:
  # The CPY-2 defaults are Volume = 2465 cm3  Area = 170 cm2 and V/A = 1450
  Vd = 1171/1000000    # chamber volume m3
  A = 0.0078           # tube area m2
  
  ## TOTAL SOIL RESPIRATION per subplot, Mg C / ha / yr.

  # remove outliers and NAs: Fluxes based on overall correction, ## Temperature and chamber correction: Temperature and Chamber height (see functions!)
  # Note: the choice of the sd_interval changes things.
  
  # Initialise dataframe for timeseries (ts)
  tst <- data.frame(datarest$plot_code, datarest$sub_plot, datarest$plot_corner_code, datarest$collar_number, datarest$measurement_code, datarest$replica, datarest$year, datarest$egm_measurement, datarest$recno, datarest$day, datarest$month, datarest$hour, datarest$soil_temp_c_out, datarest$collar_height_cm, datarest$flux)
  colnames(tst) <- c("plot_code", "sub_plot", "plot_corner_code", "collar_number", "measurement_code", "replica", "year", "egm_measurement", "recno", "day", "month", "hour", "soil_temp_c_out", "collar_height_cm", "flux")  
  
  tst$fluxt <- rm.flux.outlier(tst$flux, sd_interval=4) 
  tst$tempt <- rm.temp.outlier(tst$soil_temp_c_out, tst$month) 
  
  tst$date <- as.Date(paste(tst$year, tst$month, tst$day, sep="."), format="%Y.%m.%d") 
  tst = tst[order(tst$sub_plot,tst$date),]
  
  # Gap fill collar height
  #sp <- unique(tst$sub_plot)
  #xx <- c()

  #for (i in 1:length(sp)) {
  #  temp      <- subset(tst, tst$sub_plot == sp[i])
  #  temp$newch <- fill.na(temp$collar_height_cm)
  #  xx       <- c(xx, temp$newch)
  #}

  #tst$ch_gap_filled <- xx

  # Group by replica
  ts_total <- sqldf("SELECT tst.plot_code, tst.sub_plot, year, day, month, hour, AVG(soil_temp_c_out), AVG(ch_gap_filled), AVG(fluxt), STDEV(fluxt) FROM tst GROUP BY year, month, sub_plot")
  colnames(ts_total) <- c("plot_code", "sub_plot", "year", "day", "month", "hour", "soil_temp_c_out", "collar_height_cm", "Rs_total", "Rs_total_std")  
  ts_total$date <- as.Date(paste(ts_total$year, ts_total$month, ts_total$day, sep="."), format="%Y.%m.%d") 
  ts_total$soil_temp_c_out <- as.numeric(as.character(ts_total$soil_temp_c_out))
  
  
  # Corrections and conversions
  
  # estimation of the relative contributions of (1) surface organic litter, (2) roots, (3) mycorrhizae and (4) soil organic matter to total soil respiration
  # add a temperature correction from Sotta et al 2004 Q10=1.8 and k=0.0613
  corrsresA = exp(-0.0695*(1))
  
  # convert from umol m-2 s-1 to MgC ha month
  # convert units umol m2s-1 to MgC ha month = 1mo=2592000sec, 10000m2=1ha,
  # 1000000umol = 1 mol, 1mol = 12 g, 1000000g=1Mg
  convert = (2592000*10000*12)/(1000000*1000000)
  
  ts_total$Rs_total_MgC_ha_mo = ts_total$Rs_total*convert*corrsresA
  ts_total$Rs_total_std = ts_total$Rs_total_std*convert*corrsresA
  
  plot <- ggplot(ts_total, aes(x = date, y = Rs_total_MgC_ha_mo, na.rm = T)) +
          geom_point(data = ts_total, aes(x = date, y = Rs_total_MgC_ha_mo), size = 2, colour = ts_total$sub_plot, na.rm=T) 
  plot
  
  #ts_total1 <- subset(ts_total, sub_plot == 1 | sub_plot == 2 | sub_plot == 3 | sub_plot == 4 | sub_plot == 5)
  setwd("~/Desktop/data_sorting/Rflux")
  write.csv(ts_total, file="ESP01_ts_Rs_total.csv") 
 

 
  ### CONTROL SOIL RESPIRATION
  
  # remove outliers (> 3 SD) and NAs:
  dataresc$fluxc <- rm.flux.outlier(dataresc$flux, sd_interval = 4)                     # Discuss sd_interval with team: it makes a big difference to the data if you use 2 sd or 3 sd.
  dataresc$tempc <- rm.temp.outlier(dataresc$soil_temp_c_out, dataresc$month)
  
  # Gap fill collar height
  
 ################################################################
 # PROBLEM HERE 
 ################################################################
  
  sp <- unique(dataresc$sub_plot)
  xx <- c()
 
  for (i in 1:length(sp)) {
    temp      <- subset(dataresc, dataresc$sub_plot == sp[i])
    temp$newch <- fill.na(temp$collar_height_cm)
    xx       <- c(xx, temp$newch)
  }
 
  dataresc$ch_gap_filled <- dataresc$collar_height_cm
 
 
  ## Flux correction according to Metcalfe, RAINFOR Manual, Appendix 2, p. 75 
  dataresc$Rs_control <- fluxcorr(flux=dataresc$fluxc, temp=dataresc$tempc, ch=dataresc$ch_gap_filled, Vd=Vd, A=A, pressure=pressure)
  
  # Corrections and conversions
  
  dataresc$Rs_control_MgC_ha_mo = dataresc$Rs_control*convert*corrsresA
  dataresc$Rs_control_std = 0/0
  
  # Disturbance correction
 # correct for disturbance of soil: First look at yearly trend to see if the disturbance effect persists.  If so average for all three years
  
  dataresc$sub_plot[which(is.na(dataresc$sub_plot))] <- 13
 
  control_d   <- subset(dataresc, disturbance_code_control == "Y", select = c(sub_plot, year, Rs_control_MgC_ha_mo))
  control_ud  <- subset(dataresc, disturbance_code_control == "N", select = c(sub_plot, year, Rs_control_MgC_ha_mo))
  avg_d_yr    <- sqldf("SELECT control_d.sub_plot, control_d.year, AVG(Rs_control_MgC_ha_mo), STDEV(Rs_control_MgC_ha_mo) FROM control_d GROUP BY sub_plot, year")
  colnames(avg_d_yr) <- c("sub_plot", "year", "disturbed_control", "disturbed_control_std")
  avg_d_yr$id <- paste(avg_d_yr$sub_plot, avg_d_yr$year, sep=".") 
  avg_ud_yr    <- sqldf("SELECT control_ud.sub_plot, control_ud.year, AVG(Rs_control_MgC_ha_mo), STDEV(Rs_control_MgC_ha_mo) FROM control_ud GROUP BY sub_plot, year")
  colnames(avg_ud_yr) <- c("sub_plot", "year", "undisturbed_control", "undisturbed_control_std")
  avg_ud_yr$id <- paste(avg_ud_yr$sub_plot, avg_ud_yr$year, sep=".") 
  disturbance <- merge(avg_d_yr, avg_ud_yr, by = "id")
  colnames(disturbance) <- c("id", "sub_plot", "year", "disturbed_Rs_control", "disturbed_control_std", "sub_plot", "year", "undisturbed_control", "undisturbed_control_std")
  disturbance$dist_yr   <- as.numeric(as.character(disturbance$undisturbed_control)) - as.numeric(as.character(disturbance$disturbed_control))
  disturbance$dist_yr_std   <- sqrt(as.numeric(as.character(disturbance$undisturbed_control_std))^2 + as.numeric(as.character(disturbance$disturbed_control_std))^2)
  
  print(disturbance)
  
  dist_avg    <- mean(disturbance$dist_yr, na.rm=T) 
  dist_std    <- mean(disturbance$dist_yr_std, na.rm=T)
  discor      <- dist_avg*convert
  discorstd   <- dist_std*convert
  
 
  #### PARTITIONING SOIL RESPIRATION
    
  # remove outliers and NAs: Flux (sd > 3), Temperature and Chamber height (see soilrespiration_aux-functions.R)
  dataresp$date <- as.Date(paste(dataresp$year, dataresp$month, dataresp$day, sep="."), format="%Y.%m.%d") 
  dataresp = dataresp[order(dataresp$sub_plot,dataresp$date),]
  
  dataresp$fluxp <- rm.flux.outlier(dataresp$flux, sd_interval=4) 
  dataresp$tempp <- rm.temp.outlier(dataresp$soil_temp_c_out, dataresp$month) 
 
 # Gap fill collar height
 sp <- unique(dataresp$sub_plot)
 xx <- c()
 
 for (i in 1:length(sp)) {
   temp      <- subset(dataresp, dataresp$sub_plot == sp[i])
   temp$newch <- fill.na(temp$collar_height_cm)
   xx       <- c(xx, temp$newch)
 }
 
 dataresp$ch_gap_filled <- xx
 
  
  # Corrections and conversions

  dataresp$Rs_part_MgC_ha_mo = dataresp$fluxp*convert*corrsresA
  dataresp$Rs_part_std = 0/0
  
  dataresp$id   <- paste(dataresp$sub_plot, dataresp$day, dataresp$month, dataresp$year, sep=".")
  
  ### Calculate respiration values in each year and month for the three different treatments:
  
  # Partitioning: initialize matrices:
  
  if (partitioningoption == 1) {
    
    con1  <- subset(dataresp, treatment_code_partitioning == "con_nor_lit", select = c(id, Rs_part_MgC_ha_mo))
    con2  <- subset(dataresp, treatment_code_partitioning == "con_no_lit", select = c(id, Rs_part_MgC_ha_mo))
    con3  <- subset(dataresp, treatment_code_partitioning == "con_doub_lit", select = c(id, Rs_part_MgC_ha_mo))
    my1   <- subset(dataresp, treatment_code_partitioning == "my_nor_lit", select = c(id, Rs_part_MgC_ha_mo))
    my2   <- subset(dataresp, treatment_code_partitioning == "my_no_lit", select = c(id, Rs_part_MgC_ha_mo))
    my3   <- subset(dataresp, treatment_code_partitioning == "my_doub_lit", select = c(id, Rs_part_MgC_ha_mo))
    so1   <- subset(dataresp, treatment_code_partitioning == "so_nor_lit", select = c(id, Rs_part_MgC_ha_mo))
    so2   <- subset(dataresp, treatment_code_partitioning == "so_no_lit", select = c(id, Rs_part_MgC_ha_mo))
    so3   <- subset(dataresp, treatment_code_partitioning == "so_doub_lit", select = c(id, Rs_part_MgC_ha_mo))
    
    # build new dataframe
    tempdata = merge(con1, con2, by='id', all=T)
    tempdata = merge(tempdata, con3, by='id', all=T)
    colnames(tempdata) <- c("id", "con_nor_lit_MgC_ha_mo", "con_no_lit_MgC_ha_mo", "con_doub_lit_MgC_ha_mo")
    tempdata = merge(tempdata, my1, by='id', all=T)
    tempdata = merge(tempdata, my2, by='id', all=T)
    tempdata = merge(tempdata, my3, by='id', all=T)
    colnames(tempdata) <- c("id",  "con_nor_lit_MgC_ha_mo", "con_no_lit_MgC_ha_mo", "con_doub_lit_MgC_ha_mo", "my_nor_lit_MgC_ha_mo", "my_no_lit_MgC_ha_mo", "my_doub_lit_MgC_ha_mo")
    tempdata = merge(tempdata, so1, by='id', all=T)
    tempdata = merge(tempdata, so2, by='id', all=T)
    tempdata = merge(tempdata, so3, by='id', all=T)
    colnames(tempdata) <- c("id", "con_nor_lit_MgC_ha_mo", "con_no_lit_MgC_ha_mo", "con_doub_lit_MgC_ha_mo", "my_nor_lit_MgC_ha_mo", "my_no_lit_MgC_ha_mo", "my_doub_lit_MgC_ha_mo", "so_nor_lit_MgC_ha_mo", "so_no_lit_MgC_ha_mo", "so_doub_lit_MgC_ha_mo")
    
  } else if (partitioningoption == 2) {
    
    con_lit  <- 
    S1       <- 
    S2       <- 
    S3       <- 
    S1std    <-  
    S2std    <- 
    S3std    <- 
    
    tempdata = 
    .
    .
    .
    colnames(tempdata) <-
    
  }
  
  # merge tempdata and dataresp
  tempresp  <- sqldf("SELECT dataresp.id, dataresp.plot_code, dataresp.sub_plot, dataresp.day, dataresp.month, dataresp.year, dataresp.hour, dataresp.tempp, dataresp.ch_gap_filled, dataresp.vwc_percent_out FROM dataresp GROUP BY dataresp.id")
  tsp       <- merge(tempdata, tempresp, by = 'id', all.x = TRUE) 
  
 
  # estimate rhizosphere respiration
  # Fraction allocated to root respiration under three different treatments: control, no litter and double litter.
  if (partitioningoption == 1) {

    tsp$rr1 = ((tsp$con_no_lit_MgC_ha_mo - (tsp$so_no_lit_MgC_ha_mo + discor)) / (tsp$con_no_lit_MgC_ha_mo))
    test <- tsp$rr1[which(tsp$rr1>1)]
    test
    tsp$rr1[which(tsp$rr1>1)] = 0/0
    
    tsp$rr2 = ((tsp$con_nor_lit_MgC_ha_mo - (tsp$so_nor_lit_MgC_ha_mo + discor)) / (tsp$con_nor_lit_MgC_ha_mo))
    tsp$rr2[which(tsp$rr2>1)] = 0/0
    
    tsp$rr3 = ((tsp$con_doub_lit_MgC_ha_mo - (tsp$so_doub_lit_MgC_ha_mo + discor)) / (tsp$con_doub_lit_MgC_ha_mo))
    tsp$rr3[which(tsp$rr3>1)] = 0/0
    
    tsp$rr = (tsp$rr1 + tsp$rr2 + tsp$rr3)/3
    is.na(tsp$rr) <- !is.finite(tsp$rr) 
    tsp$rr[which(tsp$rr>1)] = 0/0
    r <- abs(tsp$rr)
    rr <- mean(r, na.rm=T)
    
    tsp$rr_std = sd(r, na.rm=T)   
    
    
  } else if (partitioningoption == 2) {
    
    tsp$rr = ((S1-(S3+discor))/S1) # Check 
    ...
  
  }
  
  ## autotrophic root respiration:
  ts_total$Rs_root_MgC_ha_mo     <- ts_total$Rs_total_MgC_ha_mo*rr
  ts_total$Rs_root_MgC_ha_mo_std <- (ts_total$Rs_total_std*rr)/sqrt(length(ts_total$Rs_total_std))
  
  ## heterotrophic respiration:
  ts_total$Rs_het_MgC_ha_mo      <- ts_total$Rs_total_MgC_ha_mo*(1-rr)
  ts_total$Rs_het_MgC_ha_mo_std  <- (ts_total$Rs_total_std*(1-rr))/sqrt(length(ts_total$Rs_total_std))
  
 plota <- ggplot(ts_total, aes(x = date, y = Rs_root_MgC_ha_mo, na.rm = T)) +
   geom_point(data = ts_total, aes(x = date, y = Rs_total_MgC_ha_mo), size = 2, colour = "darkgrey", na.rm=T) +
   geom_point(data = ts_total, aes(x = date, y = Rs_root_MgC_ha_mo), size = 2, colour = "blue", na.rm=T) + #ts_total$sub_plot
   geom_point(data = ts_total, aes(x = date, y = Rs_het_MgC_ha_mo), size = 2, colour = "red", na.rm=T)
 
 plota
 
 ###################################################################################################
 ###################################################################################################
  
  #  estimation of the relative contributions of (1) surface organic litter, (2) roots, (3) mycorrhizae and (4) soil organic matter to total soil respiration
  # add a temperature correction from Sotta et al 2004 Q10=1.8 and k=0.0613
  corrsresA = exp(-0.0695*(1))

  
  # fill gaps
  rrAfg = colMeans(t(rrA), na.rm=T)
  
  for (i in 1:12) {
    for (j in 1:(fir_yeare-fir_year+1)) {
      if (is.na(rrA[i,j]) & !is.na(totresAc[i,j])) {
        if (!is.na(rrAfg[i])) {
          rrtotresAc[i,j]    = totresAc[i,j]*rrAfg[i]
          rrtotresAcstd[i,j] = (totresAcstd[i,j]*rrAfg[i])
          hrtotresAc[i,j]    = totresAc[i,j]*(1-rrAfg[i])
          hrtotresAcstd[i,j] = totresAcstd[i,j]*(1-rrAfg[i])
        } else if (i == 12) {
          rrtotresAc[i,j]    = totresAc[i,j]*rrAfg[i-1]
          rrtotresAcstd[i,j] = (totresAcstd[i,j]*rrAfg[i-1])
          hrtotresAc[i,j]    = totresAc[i,j]*(1-rrAfg[i-1])
          hrtotresAcstd[i,j] = totresAcstd[i,j]*(1-rrAfg[i-1])
        } else {
          rrtotresAc[i,j]    = totresAc[i,j]*rrAfg[i+1]
          rrtotresAcstd[i,j] = (totresAcstd[i,j]*rrAfg[i+1])
          hrtotresAc[i,j]    = totresAc[i,j]*(1-rrAfg[i+1])
          hrtotresAcstd[i,j] = totresAcstd[i,j]*(1-rrAfg[i+1])
        }
      }    
    }
  }
  
  
  ### Relevant Data Output: totres, hrtotres
  ###  Build data frame with time series structure
  
  ##Restructure the data (according to time series structure):
  Year  <- NULL
  Month <- NULL
  Day   <- NULL
  
  for (i in 1:dim(totresAc)[2]) {
    Year[((i-1)*12+1):((i-1)*12+12)]  <- (rep(c(fir_year:fir_yeare)[i],12))
    Month[((i-1)*12+1):((i-1)*12+12)] <- (1:12)
    Day[((i-1)*12+1):((i-1)*12+12)]   <- rep(NA,12)
  }
  
  soilresp_data_monthly_ts <- data.frame(Year,Month,Day,
                                         c(rrtotresAc), c(rrtotresAcstd),
                                         c(hrtotresAc), c(hrtotresAcstd))
                                         #c(rrA1), 
                                         #c(MrA1), 
                                         #c(OMrA1), 
                                         #c(RlnlA), 
                                         #c(RldlA))
  
  colnames(soilresp.data.monthly.ts) <- c("year","month","day",  
                                          "auto_totres_MgC_ha_mo","auto_totres_std",
                                          "hetero_totres_MgC_ha_mo","hetero_totres_std")
                                          #"root_res_MgC_ha_mo",
                                          #"mycorrhizal_res_MgC_ha_mo", 
                                          #"soil_organic_matter_res_MgC_ha_mo", 
                                          #"som_nolitter_res_MgC_ha_mo", 
                                          #"som_doublelitter_res_MgC_ha_mo")
  
  
  ## Plotroutine, triggered by argument 'plotit=T'
  if (plotit == T) {
    ## Time representation of Dates as character in the vector 'dates':
    dates <- c()
    for (i in 1:length(Year)) {
      dates[i] <- as.character(strptime(paste(as.character(Year[i]),as.character(Month[i]),as.character(15),sep="-"),
                                        format="%Y-%m-%d"))
    }
    
    x11()
    par(mfrow = c(2,1))
    par(mar = c(4,4,0.5,0.5))
    plot(x = strptime(dates, format = "%Y-%m-%d"), y = soilresp.data.monthly.ts$rrtotresAc, 
         type = 'l',lwd = 2,
         xlab = "Years", ylab = "Total Respiration [Units]")
    
    plot(x = strptime(dates, format = "%Y-%m-%d"), y = soilresp.data.monthly.ts$hrtotresAc, 
         type = 'l',lty=1,
         xlab = "Years", ylab="Heterotrophic Soil Respiration [Units]")
  }
  
  # Get values for each tube rather than average
  
  # Return either monthly means (ret="monthly.means") as time series or matrix  
  switch(ret,
         monthly.means.matrix = {return(soilresp.data.monthly.matrix)},
         monthly.means.ts     = {return(soilresp.data.monthly.ts)}
  )
  
}
