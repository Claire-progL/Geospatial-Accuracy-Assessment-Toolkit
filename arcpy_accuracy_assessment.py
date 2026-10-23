import arcpy
import os
import collections

# Input parameters
shp_path = r"I:\Veg\Rocky\11samplepoint\rockypointxx.shp"
output_folder = r"I:\Veg\Rocky\11 samplepoint"
output_xls = os.path.join(output_folder, "accuracy_results.xls")

# Define red-edge index fields and class mapping
red_edge_fields = ["IRECIclasu", "MCARI2clas", "MTCIclasub", "NDRE1sub", "REPsub", "CIred_edge"]
class_labels = {3: "Healthy", 2: "Moderately_Healthy", 1: "Unhealthy"}

# Read data and build confusion matrix
def build_confusion_matrix(ground_truth, classified):
    matrix = collections.defaultdict(lambda: collections.defaultdict(int))
    for gt, cls in zip(ground_truth, classified):
        matrix[gt][cls] += 1
    return matrix

# Calculate accuracy metrics
def calculate_accuracy(matrix):
    total = sum(sum(row.values()) for row in matrix.values())
    overall = sum(matrix[cls].get(cls, 0) for cls in matrix) / total if total > 0 else 0
    
    # Producer's Accuracy
    producer = {}
    for cls in matrix:
        row_total = sum(matrix[cls].values())
        producer[cls] = matrix[cls].get(cls, 0) / row_total if row_total > 0 else 0
        
    # User's Accuracy
    user = {}
    all_cls = set(matrix.keys()).union(*(row.keys() for row in matrix.values()))
    for cls in all_cls:
        col_total = sum(row.get(cls, 0) for row in matrix.values())
        user[cls] = matrix[cls].get(cls, 0) / col_total if col_total > 0 else 0
        
    # Kappa coefficient
    pe = 0
    for cls in matrix:
        row_total = sum(matrix[cls].values())
        col_total = sum(row.get(cls, 0) for row in matrix.values())
        pe += (row_total / total) * (col_total / total)
    kappa = (overall - pe) / (1 - pe) if pe < 1 else 0
    
    return {
        "overall": overall,
        "producer": producer,
        "user": user,
        "kappa": kappa
    }

# Main process
arcpy.env.overwriteOutput = True

# Read data
ground = []
classified_data = {field: [] for field in red_edge_fields}

with arcpy.da.SearchCursor(shp_path, ["ground"] + red_edge_fields) as cursor:
    for row in cursor:
        ground.append(row[0])
        for i, field in enumerate(red_edge_fields, 1):
            classified_data[field].append(row[i])

# Calculate metrics for each red-edge index
results = []
for field in red_edge_fields:
    matrix = build_confusion_matrix(ground, classified_data[field])
    metrics = calculate_accuracy(matrix)
    
    # Extract accuracy by class
    class_metrics = {}
    for cls in [3, 2, 1]:
        class_metrics[f"Producer_{class_labels[cls]}"] = metrics["producer"].get(cls, 0) * 100
        class_metrics[f"User_{class_labels[cls]}"] = metrics["user"].get(cls, 0) * 100
        
    results.append({
        "Red_Edge_Index": field,
        "Overall_Accuracy": metrics["overall"] * 100,
        "Kappa_Coefficient": metrics["kappa"],
        **class_metrics
    })

# Create output table and export to Excel
table = arcpy.CreateTable_management("in_memory", "accuracy_table")[0]
arcpy.AddField_management(table, "Red_Edge_Index", "TEXT")
arcpy.AddField_management(table, "Overall_Accuracy", "DOUBLE")
arcpy.AddField_management(table, "Kappa_Coefficient", "DOUBLE")
for cls in [3, 2, 1]:
    arcpy.AddField_management(table, f"Producer_{class_labels[cls]}", "DOUBLE")
    arcpy.AddField_management(table, f"User_{class_labels[cls]}", "DOUBLE")

with arcpy.da.InsertCursor(table, ["Red_Edge_Index", "Overall_Accuracy", "Kappa_Coefficient",
                                   "Producer_Healthy", "User_Healthy",
                                   "Producer_Moderately_Healthy", "User_Moderately_Healthy",
                                   "Producer_Unhealthy", "User_Unhealthy"]) as cursor:
    for res in results:
        cursor.insertRow((
            res["Red_Edge_Index"],
            res["Overall_Accuracy"],
            res["Kappa_Coefficient"],
            res["Producer_Healthy"],
            res["User_Healthy"],
            res["Producer_Moderately_Healthy"],
            res["User_Moderately_Healthy"],
            res["Producer_Unhealthy"],
            res["User_Unhealthy"]
        ))

# Export to Excel
arcpy.conversion.TableToExcel(table, output_xls)
print("Processing complete, results saved to:", output_xls)
