from django.core.files.storage import default_storage


def get_private_file_url(file_key):
    """
    Return a temporary storage URL for an existing uploaded file.

    With private S3 storage enabled, this is a short-lived signed URL.
    With local development storage, this returns the local media URL.
    """
    if not file_key:
        return None

    try:
        return default_storage.url(file_key)
    except Exception:
        return None