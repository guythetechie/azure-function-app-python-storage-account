import logging
import azure.functions as func

blueprint = func.Blueprint()


@blueprint.function_name(name="proxy")
def main(request: func.HttpRequest) -> func.HttpResponse:
    logging.info("Processing HTTP request...")
    return func.HttpResponse("Response was successful.", status_code=200)
