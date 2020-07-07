import sys
from argparse import ArgumentParser


# MARK: - Preferences

arguments = ArgumentParser()
arguments.add_argument("-f", "--fraction", help="Fraction of the rows to fetch. Must be between 0 and 1.", default=0.8)
arguments.add_argument("-o", "--output", help="Where should your created model be saved? (default: model.mlmodel)", default="model.mlmodel")
arguments.add_argument("-mi", "--maxIterations", help="The number of training iterations. If 0, then it will be automatically be determined based on the amount of data you provide. (default: 0)", default=0)
arguments.add_argument("-s", "--batchSize", help="The number of images per training iteration. If 0, then it will be automatically determined based on resource availability. (default: 0)", default=0)
arguments.add_argument("-v", "--verbose", help="If True, print progress updates and model details. (default: true)", default="true")

options = vars(arguments.parse_args())


def toInt(v):
    """ Try to turn a variable into an int """
    try:
        v = int(options["maxIterations"])
    except:
        print("Warning: --maxIterations must be a valid integer value!")
        sys.exit(1)

    return v

# Option: proportions
try:
    split = float(options["proportions"])
except:
    print("Warning: --proportions must be a value between 0.0 to 1.0!")
    sys.exit(1)


# Option: max iterations
maxIterations = toInt(options["maxIterations"])

# Option: batch size
batchSize = toInt(options["batchSize"])

# Option: verbose
if options["verbose"] == "true" or options["verbose"] == "yes":
    verbose = True
elif options["verbose"] == "false" or options["verbose"] == "no":
    verbose = False
else:
    print("Warning: --verbose must either be true/yes or false/no.")
    sys.exit(1)

# Option: filename
filename = options["output"]

# MARK: - Turi Create

import turicreate
import Dataset

# Load our data
data = Dataset.load()

# Split our data into training and testing sets
train, test = data.random_split(split)

# Create our model
model = turicreate.object_detector.create(data, max_iterations=maxIterations, verbose=verbose, batch_size=batchSize)

# Evaluate our model
metrics = model.evaluate(test)
print(metrics)

# Export it to our output path
model.export_coreml(filename)
