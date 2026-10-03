from storages.backends.s3 import S3Storage


class PrivateMediaStorage(S3Storage):
    """
    Central private storage for all Academy ERP uploaded media.

    Used for:
    - Course videos
    - PDFs and study materials
    - Assignment files
    - Banner images
    """

    location = "media"
    default_acl = None
    file_overwrite = False
    querystring_auth = True