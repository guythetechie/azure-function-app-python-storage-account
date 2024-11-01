import logging
import json
import azure.identity as identity
import azure.functions as func
import azure.storage.blob as blob

blueprint = func.Blueprint()


@blueprint.function_name(name="import_with_storage_queue")
@blueprint.queue_trigger(arg_name="message",
                         queue_name="%STORAGE_ACCOUNT_QUEUE_NAME%",
                         connection="STORAGE_ACCOUNT_CONNECTION")
def main(message: func.QueueMessage) -> None:
    logging.info('Python queue trigger function processed a queue item: %s',
                 message.get_body().decode('utf-8'))

    body = json.loads(message.get_body())
    blobUrl = body["data"]["url"]
    logging.info(f"Blob URL: {blobUrl}")

    credential = identity.DefaultAzureCredential()
    blobClient = blob.BlobClient.from_blob_url(blobUrl, credential)
    logging.info('Blob %s size is %d bytes',
                 blobClient.blob_name,
                 blobClient.get_blob_properties().size)
