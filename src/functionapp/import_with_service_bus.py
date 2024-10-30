import logging
import azure.functions as func
import os
import azure.storage.blob as blob

blueprint = func.Blueprint()


@blueprint.function_name(name="import_with_service_bus")
@blueprint.service_bus_topic_trigger(arg_name="message",
                                     topic_name="%SERVICE_BUS_TOPIC_NAME%",
                                     subscription_name="%SERVICE_BUS_SUBSCRIPTION_NAME%",
                                     connection="SERVICE_BUS_CONNECTION")
def main(message: func.ServiceBusMessage) -> None:
    # logging.info("Creating blob service client...")
    # storage_account_connection_string = os.getenv(
    #     "STORAGE_ACCOUNT_CONNECTION_STRING")
    # container_name = os.getenv("STORAGE_ACCOUNT_CONTAINER_NAME")
    # blob_name = os.getenv("STORAGE_ACCOUNT_BLOB_NAME")
    # blob_container_client = blob.ContainerClient.from_connection_string(
    #     storage_account_connection_string, container_name)

    # logging.info("Downloading blob...")
    # blob_stream = blob_container_client.download_blob(blob_name)
    # blob_bytes = blob_stream.readall()
    # logging.info(f"Blob content: {blob_bytes}")

    # for blobName in blob_container_client.list_blob_names():
    #     logging.info(f"Blob name: {blobName}")
    #     blob_container_client.download_blob(blobName).readall()
    logging.info(f"Message content: {message.get_body().decode("utf-8")}")
