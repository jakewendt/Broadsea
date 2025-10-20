#!/usr/bin/env Rscript


devtools::install_github("OHDSI/ETL-Synthea")

library(ETLSyntheaBuilder)


#	DatabaseConnector::downloadJdbcDrivers("postgresql",pathToDriver="~/Downloads/")

cd <- DatabaseConnector::createConnectionDetails(
  dbms     = "postgresql", 
  server   = "localhost/synthea10", 
  user     = "postgres", 
  password = "", 
  port     = 5432,
  pathToDriver = "~/Downloads/"
)

cdmSchema      <- "cdm_synthea10"
cdmVersion     <- "5.4"
syntheaVersion <- "3.0.0"
syntheaSchema  <- "native"
vocabFileLoc   <- "~/Downloads/synthea_1m_fhir_3_0_May_24/vocabulary_download_v5"

ETLSyntheaBuilder::CreateCDMTables(connectionDetails = cd, cdmSchema = cdmSchema, cdmVersion = cdmVersion)

ETLSyntheaBuilder::CreateSyntheaTables(connectionDetails = cd, syntheaSchema = syntheaSchema, syntheaVersion = syntheaVersion)

ETLSyntheaBuilder::LoadVocabFromCsv(connectionDetails = cd, cdmSchema = cdmSchema, vocabFileLoc = vocabFileLoc)

#	Should correct this function call ... ? They appear to be just warnings.
#	1: `type_convert()` only converts columns of type 'character'.
#	- `df` has no columns of type 'character' 
#	2: In data.table::fread(file = paste0(vocabFileLoc, "/", csv), stringsAsFactors = FALSE,  :
#	  Found and resolved improper quoting out-of-sample. First healed line 51465: <<44833612	"ventilation" pneumonit	4180186>>. If the fields are not quoted (e.g. field separator does not appear within any field), try quote="" to avoid this warning.
#	3: In data.table::fread(file = paste0(vocabFileLoc, "/", csv), stringsAsFactors = FALSE,  :
#	  Found and resolved improper quoting out-of-sample. First healed line 9139: <<44829276	"Light-for-dates" without mention of fetal malnutrition, unspecified [weight]	Condition	ICD9CM	5-dig billing code		764.00	19700101	20991231	>>. If the fields are not quoted (e.g. field separator does not appear within any field), try quote="" to avoid this warning.
#	4: `type_convert()` only converts columns of type 'character'.
#	- `df` has no columns of type 'character' 




syntheaFileLocs <- c(
"~/Downloads/synthea_1m_fhir_3_0_May_24/output_1/csv",
"~/Downloads/synthea_1m_fhir_3_0_May_24/output_2/csv",
"~/Downloads/synthea_1m_fhir_3_0_May_24/output_3/csv",
"~/Downloads/synthea_1m_fhir_3_0_May_24/output_4/csv",
"~/Downloads/synthea_1m_fhir_3_0_May_24/output_5/csv",
"~/Downloads/synthea_1m_fhir_3_0_May_24/output_6/csv",
"~/Downloads/synthea_1m_fhir_3_0_May_24/output_7/csv",
"~/Downloads/synthea_1m_fhir_3_0_May_24/output_8/csv",
"~/Downloads/synthea_1m_fhir_3_0_May_24/output_9/csv",
"~/Downloads/synthea_1m_fhir_3_0_May_24/output_10/csv",
"~/Downloads/synthea_1m_fhir_3_0_May_24/output_11/csv",
"~/Downloads/synthea_1m_fhir_3_0_May_24/output_12/csv"
)
#syntheaFileLoc <- "~/Downloads/synthea_1m_fhir_3_0_May_24/output_1/csv"


#	Do this one more time, but loop over all synthea dirs
for( syntheaFileLoc in syntheaFileLocs ){
	print(syntheaFileLoc)
	ETLSyntheaBuilder::LoadSyntheaTables(connectionDetails = cd, syntheaSchema = syntheaSchema, syntheaFileLoc = syntheaFileLoc)
}

ETLSyntheaBuilder::CreateMapAndRollupTables(connectionDetails = cd, cdmSchema = cdmSchema, syntheaSchema = syntheaSchema, cdmVersion = cdmVersion, syntheaVersion = syntheaVersion)

## Optional Step to create extra indices
ETLSyntheaBuilder::CreateExtraIndices(connectionDetails = cd, cdmSchema = cdmSchema, syntheaSchema = syntheaSchema, syntheaVersion = syntheaVersion)

ETLSyntheaBuilder::LoadEventTables(connectionDetails = cd, cdmSchema = cdmSchema, syntheaSchema = syntheaSchema, cdmVersion = cdmVersion, syntheaVersion = syntheaVersion)



