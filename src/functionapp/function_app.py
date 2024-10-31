import logging
import json
import azure.identity as identity
import azure.functions as func
import azure.storage.blob as blob

app = func.FunctionApp()


@app.function_name(name="import_with_storage_queue")
@app.queue_trigger(arg_name="message",
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
    blobContent = blobClient.download_blob().readall()
    logging.info(f"Blob content: {blobContent}")

# import azure.functions as func
# # from import_on_timer import blueprint as timer_blueprint
# from import_with_storage_queue import bp as storage_queue_blueprint

# app = func.FunctionApp()

# # app.register_functions(timer_blueprint)
# app.register_blueprint(storage_queue_blueprint)


# import azure.functions as func
# from functionapp.import_with_storage_queue import blueprint as service_bus_blueprint
# from import_on_timer import blueprint as timer_blueprint

# app = func.FunctionApp()
# app.register_functions(service_bus_blueprint)
# app.register_functions(timer_blueprint)
