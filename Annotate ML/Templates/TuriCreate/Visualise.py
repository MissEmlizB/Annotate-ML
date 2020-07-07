import turicreate
import Dataset


data = Dataset.load()

# Draw bounding boxes over our photos
data["image_with_ground_truth"] = turicreate.object_detector.util.draw_bounding_boxes(data["image"], data["annotations"])
data.explore()
