import logging
import azure.functions as func
import aiohttp

blueprint = func.Blueprint()


@blueprint.function_name(name="proxy")
async def main(request: func.HttpRequest) -> func.HttpResponse:
    logging.info("Processing HTTP request...")

    return func.HttpResponse("Processed.", status_code=200)