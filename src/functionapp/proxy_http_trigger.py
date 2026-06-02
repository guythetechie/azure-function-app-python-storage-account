import logging
import azure.functions as func
import azurefunctions.extensions.http.fastapi as fast_api

blueprint = func.Blueprint()


@blueprint.function_name(name="proxy")
async def main(request: fast_api.Request) -> fast_api.Response:
    logging.info("Processing HTTP request...")

    # Extract destination URL from the body
    destination_url = request.get_json().get("url")
    if not destination_url:
        return func.HttpResponse("Missing destination URL.", status_code=400)

    # Make the request to the destination URL
    response = fast_api. requests.get(destination_url)

    return fast_api.Response(content=response.content, status_code=response.status_code)
