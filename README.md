# Geospatial Accuracy Assessment & Statistical Toolkit 🌍📊

A robust data science toolkit designed for spatial accuracy assessment, anomaly detection, and statistical thresholding in remote sensing workflows. 

This repository provides automated scripts to process extracted raster values (e.g., Vegetation Indices, Water Indices), compute confusion matrices, evaluate classification accuracy, and utilize robust statistical methods (like IQR-based outlier removal) to determine optimal classification thresholds.

## 🛠️ Tech Stack
* **Python (ArcPy / ArcMap & ArcGIS Pro):** Used for iterating over spatial sample points, constructing confusion matrices, and calculating Overall Accuracy, Producer's/User's Accuracy, and the Kappa Coefficient.
* **R (ggplot2, dplyr, tidyr):** Used for processing raw spectral responses, executing quartile-based outlier removal (Boxplot method), and generating publication-ready statistical visualizations.

## 🚀 Core Features
1. **Automated Accuracy Assessment (`arcpy_accuracy_assessment.py`):** 
   Reads true ground labels and predicted classification values from shapefile attribute tables, dynamically calculating multi-class confusion matrices and exporting evaluation metrics directly to Excel.
2. **Spectral Outlier & Threshold Analysis (`outlier_boxplot_analysis.R`):** 
   Statistically separates target features (e.g., health levels of vegetation or water vs. non-water) by calculating the 25th and 75th percentiles, removing extreme outliers, and visualizing index distributions via advanced boxplots.

## 📝 Usage
* Ensure you have `arcpy` correctly configured within your ArcGIS Pro / ArcMap Python environment.
* R scripts require standard tidyverse packages (`dplyr`, `tidyr`, `ggplot2`, `readxl`, `writexl`).
