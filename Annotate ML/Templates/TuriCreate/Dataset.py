import turicreate


EXPORT_PATH = "%PATH%"

def load():
    """ Loads the exported data into an SFrame """
    annotations = turicreate.SFrame(data="%s/annotations.csv" % (EXPORT_PATH))

    # Load our images
    images = list()

    for path in annotations["path"]:
        image = turicreate.Image("%s/%s" % (EXPORT_PATH, path))
        images.append(image)

    data = annotations
    data["image"] = images

    return data
