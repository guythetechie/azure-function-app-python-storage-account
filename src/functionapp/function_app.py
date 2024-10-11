import logging
import azure.functions as func
import os
import azure.storage.blob as blob

app = func.FunctionApp()


@app.function_name(name="import_storage_files")
@app.timer_trigger(schedule="0 0 0 * * *",
                   arg_name="timer",
                   run_on_startup=True)
def test_function(timer: func.TimerRequest) -> None:
    logging.info("Creating blob service client...")
    storage_account_connection_string = os.getenv(
        "DEPLOYMENT_STORAGE_ACCOUNT_CONNECTION_STRING")
    container_name = os.getenv("STORAGE_ACCOUNT_CONTAINER_NAME")
    blob_container_client = blob.ContainerClient.from_connection_string(
        storage_account_connection_string, container_name)

    for blobName in blob_container_client.list_blob_names():
        logging.info(f"Blob name: {blobName}")
