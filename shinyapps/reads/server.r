# download public RNA-Seq data from ARCHS4
# needs to run GSEinfo.R script to generate GSE info file
library(shiny)
library(DT) # for renderDataTable
library("rhdf5")

destination_fileH = "../../countsData/human_matrix.h5"
destination_fileM = "../../countsData/mouse_matrix.h5"
sampleInfoFile = "sampleInfo.txt"
GSEInfoFile = "../../countsData/GSEinfo.txt"

if(file.exists(sampleInfoFile)) {
  sample_info =read.table(sampleInfoFile, sep="\t",header=T )
} else {   # create sample info
  # Check if gene expression file was already downloaded, if not in current directory download file form repository
  if(!file.exists(destination_fileH)) {
    print("Downloading compressed gene expression matrix.")
    url = "https://s3.amazonaws.com/mssm-seq-matrix/human_matrix.h5"
    download.file(url, destination_file, quiet = FALSE)
  } else{
      print("Local file already exists.")
  }
    # Check if gene expression file was already downloaded, if not in current directory download file form repository
    if(!file.exists(destination_fileM)){
      print("Downloading compressed gene expression matrix.")
      url = "https://s3.amazonaws.com/mssm-seq-matrix/human_matrix.h5"
      download.file(url, destination_file, quiet = FALSE)
    } else{
      print("Local file already exists.")
    }

      # if(!file.exists(infoFile)){
      destination_file = destination_fileH
      # Retrieve information from compressed data
      GSMs = h5read(destination_file, "meta/Sample_geo_accession")
      tissue = h5read(destination_file, "meta/Sample_source_name_ch1")
      #genes = h5read(destination_file, "meta/genes")
      sample_title = h5read(destination_file, "meta/Sample_title")
      sample_series_id = h5read(destination_file, "meta/Sample_series_id")

      species = rep("human",length(GSMs))
      sample_info = cbind(GSMs, tissue, sample_title,sample_series_id,species)
      H5close()

      destination_file = destination_fileM
      # Retrieve information from compressed data
      GSMs = h5read(destination_file, "meta/Sample_geo_accession")
      tissue = h5read(destination_file, "meta/Sample_source_name_ch1")
      #genes = h5read(destination_file, "meta/genes")
      sample_title = h5read(destination_file, "meta/Sample_title")
      sample_series_id = h5read(destination_file, "meta/Sample_series_id")

      species = rep("mouse",length(GSMs))
      sample_infoM = cbind(GSMs, tissue, sample_title,sample_series_id,species)
      H5close()
      # sample info for both human and mouse
      sample_info = as.data.frame( rbind(sample_info, sample_infoM) )
      write.table(sample_info, sampleInfoFile, sep="\t",row.names=F)
}

humanNDataset <<- length(unique(sample_info$sample_series_id[which(sample_info$species == "human")]) )
mouseNDataset <<- length(unique(sample_info$sample_series_id[which(sample_info$species == "mouse")]) )

# Define server logic ----
server <- function(input, output) {
  Search <- reactive({
    if (is.null(input$SearchGSE))   return(NULL)
    keyword = toupper(input$SearchGSE)
    keyword = gsub(" ","",keyword)
    ix = which(sample_info[,4]== keyword)

    if(length(ix) == 0)
      return(NULL)
    else {
    #sample ids
    samp = sample_info[ix,1]   # c("GSM1532588", "GSM1532592" )
    if( names(sort(table(sample_info[ix,5]),decreasing=T))[1] == "human" )
      destination_file = destination_fileH
    if( names(sort(table(sample_info[ix,5]),decreasing=T))[1] == "mouse" )
      destination_file = destination_fileM

    # Identify columns to be extracted
    samples = h5read(destination_file, "meta/Sample_geo_accession")
    sample_locations = which(samples %in% samp)

    # extract gene expression from compressed data
    genes = h5read(destination_file, "meta/genes")
    expression = h5read(destination_file, "data/expression", index=list(1:length(genes), sample_locations))
    tissue = h5read(destination_file, "meta/Sample_source_name_ch1")
    sample_title = h5read(destination_file, "meta/Sample_title")
    H5close()

    rownames(expression) <-paste(" ",genes)
    colnames(expression) <- paste( samples[sample_locations], sample_title[sample_locations], sep=" ")
    expression <- expression[,order(colnames(expression))]
    tem = sample_info[ix,c(5,1:3)]
    tem = tem[order(tem[,4]),]
    colnames(tem) <- c("Species", "Sample ID","Tissue","Sample Title")
    if(dim(tem)[1]>50) tem = tem[1:50,]
    return( list(info=tem, counts = expression ) )
    }
 })
  output$samples <- renderTable({
    if (is.null(input$SearchGSE)  )   return(NULL)
    if (is.null(Search() )  )   return(as.matrix("No dataset found!"))
    Search()$info
  },bordered = TRUE)

  output$downloadSearchedData <- downloadHandler(
    filename = function() { paste(input$SearchGSE,".csv",sep="")},
    content = function(file) {
      write.csv( Search()$counts, file )	    }
  )

output$SearchGSE <- DT::renderDataTable({

    if (!file.exists( GSEInfoFile ))   return(NULL)
	x=read.table(GSEInfoFile, sep="\t",header=T )
	x
  })
output$humanNsamplesOutput <- renderText({
    if (is.null(input$SearchGSE)  )   return(NULL)
	 return(as.character(humanNDataset))
	})
output$mouseNsamplesOutput <- renderText({
    if (is.null(input$SearchGSE)  )   return(NULL)
	 return(as.character(mouseNDataset))
	})
}
