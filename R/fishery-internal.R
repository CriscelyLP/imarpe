
# Internal functions for the class fishery --------------------------------

#Funcion para obtener la data para desembarques o esfuerzo por puerto
.getFisheryData = function(x, fileName, fleet, varType, toTons, sp, start, end, port, efforType) {

  fleeTable = fleet
  dataBase  = .readSegFile(file = x)
  dataBase[is.na(dataBase)] =  0

  if(varType == "landing"){
    dataBase = data.frame(dataBase[c(1:3)],
                          dataBase[seq(4, length(colnames(dataBase)), by = 2)]/ifelse(isTRUE(toTons), 1000, 1))
  } else {
    dataBase = data.frame(dataBase[seq(1,3)], dataBase[seq(5, length(colnames(dataBase)), by = 2)])
  }

  dataBase = .trimData(x = dataBase, start = start, end = end)

  ports = dataBase[seq(4, length(colnames(dataBase)))]
  namesPorts = vector()
  for(i in seq_len(ncol(ports))){
    namesP = strsplit(x = names(ports), split = "_")[[i]][1]
    namesPorts = c(namesPorts, namesP)
  }
  colnames(dataBase) = c(colnames(dataBase)[c(1:3)], namesPorts)

  if(is.null(port)){
    dataTable = dataBase
  } else {
    dataTable = dataBase[, c(1:3)]
    dataTable[, port] = dataBase[, port]
  }

  if(varType == "landing"){
    efforType = NULL
  } else{
    efforType = efforType
  }

  info = list(file    = fileName,
              records = nrow(dataTable),
              months  = length(rle(dataTable$month)$values),
              years   = length(unique(dataTable$year)),
              ports   = length(colnames(dataTable))-3,
              sp      = sp,
              varType = varType,
              efforType = efforType)

  output = list(data = dataTable, info = info, fleeTable = fleeTable)
  class(output) = c("fishery")
  return(output)
}

#Funcion para sumar los desembarques o esfuerzos para todos los puertos
.getSumPorts.fishery = function(object, language) {

  dataBase = object$data
  ports    = cbind(dataBase[, seq(4, length(colnames(dataBase)))])

  dataTable = data.frame(dataBase[, c(1:3)], apply(ports, 1, sum))

  if(object$info$varType == "landing"){
    if(language == "english"){
      colnames(dataTable) = c("year", "month", "day", "landing")
    } else {
      colnames(dataTable) = c("anho", "mes", "dia", "desembarque")
      dataTable$mes       = engToSpa(dataTable$mes)
    }} else {
    if(language == "english"){
      colnames(dataTable) =  c("year", "month", "day", "effort")
    } else {
      colnames(dataTable) = c("anho", "mes", "dia", "esfuerzo")
      dataTable$mes       = engToSpa(dataTable$mes)
    }}

  return(dataTable)
}

#Funcion para obtener los desembarques o esfuerzos totales para cada puerto
.getPorts.fishery = function(object, language) {

  dataBase = object$data
  ports = dataBase[seq(4, length(colnames(dataBase)))]
  namesPorts = vector()

  for(i in seq_len(ncol(ports))){
    namesP = strsplit(x = names(ports), split = "_")[[i]][1]
    namesPorts = c(namesPorts, namesP)
  }

  dataTable = data.frame(apply(ports, 2, sum), row.names = NULL)
  rownames(dataTable) = capitalize(namesPorts)

  if(object$info$varType == "landing"){
    if(language == "english"){colnames(dataTable) = "Landing"} else {colnames(dataTable) = "Desembarque"}
  } else {
    if(language == "english"){colnames(dataTable) = "Effort"} else {colnames(dataTable) = "Esfuerzo"}
  }

  # Ordering ports in relation to the names
  ports    = rownames(dataTable)
  portData = getPort(myPorts = ports)
  rownames(dataTable) = portData$data$name
  dataTable$lat = portData$data$lat
  dataTable = dataTable[with(dataTable, order(dataTable$lat, decreasing = TRUE)), ]
  dataTable$lat = NULL

  return(dataTable)
}

#Funcion para obtener los desembarques o esfuerzo totales por meses
.getMonth.fishery = function (object, language) {

  dataBase  = .getSumPorts.fishery(object=object, language=language)
  dataTable = tapply(dataBase[,4], list(dataBase[,2], dataBase[,1]),
                     sum, na.remove = FALSE)
  years = colnames(dataTable)

  monthsTable = row.names(dataTable)
  if(language=="english"){vectorMonths = month.abb} else {vectorMonths = engToSpa(month.abb)}
  sortMonth   = sort(match(monthsTable, vectorMonths), decreasing = FALSE)
  order       = vectorMonths[sortMonth]

  dataTable = dataTable[order, ]
  dataTable = as.data.frame(dataTable)
  colnames(dataTable) = unique(years)

  if(language == "english"){
    rownames(dataTable) = month.abb[sortMonth]
    colnames(dataTable) = years
  } else {
    rownames(dataTable) = engToSpa(month.abb[sortMonth])
    colnames(dataTable) = years
  }

  dataTable[is.na(dataTable)] = 0

  return(dataTable)
}

#Funcion para obtener los desembarques o esfuerzo totales por anhos
.getYear.fishery = function(object, language) {

  dataBase = .getSumPorts.fishery(object=object, language=language)
  dataTable = tapply(dataBase[,4], list(dataBase[,1]), sum, na.remove = FALSE)
  dataTable = data.frame(dataTable)

  if(object$info$varType == "landing"){
    if(language == "english"){colnames(dataTable) = "Landing"} else {colnames(dataTable) = "Desembarque"}
  } else {
    if(language == "english"){colnames(dataTable) = "Effort"} else {colnames(dataTable) = "Esfuerzo"}
  }


  return(dataTable)
}


#GRAFICAS
#Funcion para plotear el desembarque o esfuerzo diario
.plotDays.fishery = function(x, main = NULL, xlab=NULL, ylab = NULL, language, col = "blue",
                             daysToPlot, cex.axis = 0.8, cex.names=0.7, cex.main = 1, ...) {

  dataBase   = .getSumPorts.fishery(object = x, language = language)

  if(unique(daysToPlot %in% "all")){
    vectorDays = paste0(as.character(dataBase[,3]),"-", capitalize(as.character(dataBase[,2])))
  } else {
    vectorDays = paste0(as.character(dataBase[,3]),"-", capitalize(as.character(dataBase[,2])))
    daysToPlot = which(as.numeric(dataBase[,3]) %in% daysToPlot)
    daysToPlot = vectorDays[daysToPlot]
    vectorDays[! vectorDays %in% daysToPlot] = NA
  }

  if(is.null(main)){
    if(x$info$varType == "landing"){
      if(language == "english"){main = "Daily landing"} else {main = "Desembarque diario"}
    } else {
      if(language == "english"){main = "Daily effort"} else {main = "Esfuerzo diario"}}}

  efforType  = x$info$efforType
  if(!is.null(efforType)){
    if(efforType == "viaje"){
      if(language == "spanish"){labUnits = "Número de viajes" } else {labUnits = "Number of travels"}}
    if(efforType == "capacidad_bodega"){
      if(language == "spanish"){labUnits = expression(paste("Capacidad bodega (", m^3, ")")) } else {labUnits = expression(paste("Hold storage (", m^3, ")"))}}
    if(efforType == "anzuelos"){
      if(language == "spanish"){labUnits = "Número de anzuelos)" } else {labUnits = "Number of fish hook"}}
    if(efforType == "embarcaciones"){
      if(language == "spanish"){labUnits = "Número de embarcaciones)" } else {labUnits = "Number of boats"}}
  }

  if(is.null(ylab)){
    if(x$info$varType == "landing"){
      if(language == "english"){ylab = "Landing (t)"} else {ylab = "Desembarque (t)"}
    } else {ylab = labUnits}}

  par(mar = c(4,4.5,2,0.5))
  barplot(dataBase[,4], main=main, xlab=xlab, ylab=ylab, col=col, names.arg = FALSE,
          ylim=c(0,max(dataBase[,4])*1.2), cex.names=cex.names, axes=FALSE, cex.main = cex.main, ...)
  AxisDate = seq(0.7, by=1.2, length.out=length(vectorDays))
  NonNa =! is.na(vectorDays)
  axis(1, at=AxisDate[NonNa], labels=vectorDays[NonNa], las=2, cex.axis=cex.axis)
  axis(2, las=2, cex.axis=cex.axis)
  box()

  return(invisible())

}

#Funcion para plotear el desembarque mensual
.plotMonths.fishery = function(x, main = NULL, xlab = NULL, ylab = NULL, language, col = "blue",
                               cex.axis = 0.8, cex.names=0.7, cex.main =  1,...) {

  dataBase = .getMonth.fishery(object = x, language = language)
  vectorYears = as.numeric(colnames(dataBase))

  monthPlot = as.vector(as.matrix(dataBase[,(colnames(dataBase))]))
  monthPlot = monthPlot[!is.na(monthPlot)]

  namesMonthPlot  = capitalize(rep(rownames(dataBase), length.out = length(monthPlot)))

  if(is.null(main)){
    if(x$info$varType == "landing"){
      if(language == "english"){main = "Monthly landing"} else {main = "Desembarque mensual"}
    } else {
      if(language == "english"){main = "Monthly effort"} else {main = "Esfuerzo mensual"}}}

  efforType  = x$info$efforType
  if(!is.null(efforType)){
    if(efforType == "viaje"){
      if(language == "spanish"){labUnits = "Número de viajes" } else {labUnits = "Number of travels"}}
    if(efforType == "capacidad_bodega"){
      if(language == "spanish"){labUnits = expression(paste("Capacidad bodega (", m^3, ")")) } else {labUnits = expression(paste("Hold storage (", m^3, ")"))}}
    if(efforType == "anzuelos"){
      if(language == "spanish"){labUnits = "Número de anzuelos)" } else {labUnits = "Number of fishhook"}}
    if(efforType == "embarcaciones"){
      if(language == "spanish"){labUnits = "Número de embarcaciones)" } else {labUnits = "Number of boats"}}
  }

  if(is.null(ylab)){
    if(x$info$varType == "landing"){
      if(language == "english"){ylab = "Landing (t)"} else {ylab = "Desembarque (t)"}
    } else {ylab = labUnits}}

  par(mar = c(4,4.5,2,0.5))
  barplot(monthPlot, main=main, xlab=xlab, ylab=ylab, col=col, names.arg=FALSE,
          ylim=c(0, max(monthPlot)*1.2), cex.names=cex.names, axes=FALSE, cex.main=cex.main, ...)
  axis(1, at=seq(0.7, by=1.2, length.out=length(monthPlot)), labels=namesMonthPlot,
       las=1, cex.axis=cex.axis, line=0)
  axis(1, at=seq(0.7,by=1.2, length.out=length(monthPlot)),
       labels=rep(vectorYears,each=12)[1:length(monthPlot)], las=1, cex.axis=cex.axis, line=1, tick=FALSE)
  axis(2, las=2, cex.axis=cex.axis)
  box()

  return(invisible())

}

#Funcion para plotear el desembarque anual
.plotYears.fishery = function(x, main=NULL, xlab=NULL, ylab=NULL, language, col = "blue",
                              cex.axis = 0.8, cex.names=0.7, cex.main = 1, ...) {

  dataBase = .getYear.fishery(object = x, language = language)
  years = as.numeric(rownames(dataBase))

  if(is.null(main)){
    if(x$info$varType == "landing"){
      if(language == "english"){main = "Yearly landing"} else {main = "Desembarque anual"}
    } else {
      if(language == "english"){main = "Yearly effort"} else {main = "Esfuerzo anual"}}}

  efforType  = x$info$efforType
  if(!is.null(efforType)){
    if(efforType == "viaje"){
      if(language == "spanish"){labUnits = "Número de viajes" } else {labUnits = "Number of travels"}}
    if(efforType == "capacidad_bodega"){
      if(language == "spanish"){labUnits = expression(paste("Capacidad bodega (", m^3, ")")) } else {labUnits = expression(paste("Hold storage (", m^3, ")"))}}
    if(efforType == "anzuelos"){
      if(language == "spanish"){labUnits = "Número de anzuelos)" } else {labUnits = "Number of fishhook"}}
    if(efforType == "embarcaciones"){
      if(language == "spanish"){labUnits = "Número de embarcaciones)" } else {labUnits = "Number of boats"}}
  }

  if(is.null(ylab)){
    if(x$info$varType == "landing"){
      if(language == "english"){ylab = "Landing (t)"} else {ylab = "Desembarque (t)"}
    } else {ylab = labUnits}}

  par(mar = c(2.5,4.5,2,0.5))
  barplot(dataBase[,1], main=main, xlab=xlab, ylab=ylab, col=col, names.arg=FALSE,
          ylim=c(0,max(dataBase)*1.2), cex.names=cex.names, axes=FALSE, cex.main = cex.main, ...)
  axis(1, at=seq(0.7, by=1.2, length.out=length(years)), labels=years, las=1,
       cex.axis=cex.axis)
  axis(2, las=2, cex.axis=cex.axis)
  box()

  return(invisible())

}
