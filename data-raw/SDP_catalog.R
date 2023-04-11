## code to prepare `SDP_catalog` dataset goes here
SDP_catalog <- read.csv("https://rmbl-sdp.s3.us-east-2.amazonaws.com/data_products/SDP_product_table_04_11_2023.csv")
usethis::use_data(SDP_catalog, overwrite = TRUE, internal = TRUE)
