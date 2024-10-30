import logging
import azure.functions as func
import os
import azure.storage.blob as blob

blueprint = func.Blueprint()


@blueprint.function_name(name="import_on_timer")
@blueprint.timer_trigger(schedule="0 0 0 * * *",
                         arg_name="timer",
                         run_on_startup=False)
def main(timer: func.TimerRequest) -> None:
    logging.info("Creating blob service client...")
    storage_account_connection_string = os.getenv(
        "STORAGE_ACCOUNT_CONNECTION_STRING")
    container_name = os.getenv("STORAGE_ACCOUNT_CONTAINER_NAME")
    blob_name = os.getenv("STORAGE_ACCOUNT_BLOB_NAME")
    blob_container_client = blob.ContainerClient.from_connection_string(
        storage_account_connection_string, container_name)

    logging.info("Downloading blob...")
    blob_stream = blob_container_client.download_blob(blob_name)
    blob_bytes = blob_stream.readall()
    logging.info(f"Blob content: {blob_bytes}")

    for blobName in blob_container_client.list_blob_names():
        logging.info(f"Blob name: {blobName}")
        blob_container_client.download_blob(blobName).readall()
